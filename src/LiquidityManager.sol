// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/types/BalanceDelta.sol";

/**
 * @title LiquidityManager
 * @notice Manages liquidity in Uniswap v4 WBTC/ETH pool
 */
contract LiquidityManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PoolId for IPoolManager;

    // ====== Constants ======
    uint24 public constant POOL_FEE = 3000; // 0.3%
    int24 public constant TICK_SPACING = 60;
    uint24 public constant RANGE_WIDTH = 500; // ±5% range in basis points
    uint256 public constant MIN_LIQUIDITY_AMOUNT = 0.01 ether;
    uint256 public constant SLIPPAGE_TOLERANCE = 50; // 0.5%

    // ====== State Variables ======
    IPoolManager public immutable poolManager;
    IERC20 public immutable wbtcToken;
    address public feeRecipient;
    PoolKey public poolKey;
    uint256 public positionId;

    // ====== Events ======
    event LiquidityAdded(uint256 positionId, uint256 wbtcAmount, uint256 ethAmount);
    event LiquidityRemoved(uint256 positionId, uint256 wbtcAmount, uint256 ethAmount);
    event PositionRebalanced(uint256 positionId, int24 tickLower, int24 tickUpper);
    event SwapExecuted(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96);

    constructor(
        address _poolManager,
        address _wbtcToken,
        address _feeRecipient
    ) {
        require(_poolManager != address(0), "Invalid pool manager");
        require(_wbtcToken != address(0), "Invalid WBTC token");
        require(_feeRecipient != address(0), "Invalid fee recipient");

        poolManager = IPoolManager(_poolManager);
        wbtcToken = IERC20(_wbtcToken);
        feeRecipient = _feeRecipient;

        // Initialize pool key for WBTC/ETH
        poolKey = PoolKey({
            currency0: Currency.wrap(_wbtcToken),
            currency1: Currency.wrap(address(0)), // ETH
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });

        // Approve max WBTC for pool manager
        wbtcToken.approve(address(poolManager), type(uint256).max);
    }

    /**
     * @notice Add liquidity to the WBTC/ETH pool with ETH only
     * @dev Swaps half of ETH to WBTC and adds liquidity
     */
    function addLiquidity() external payable nonReentrant {
        require(msg.value >= MIN_LIQUIDITY_AMOUNT, "Insufficient ETH");

        // Get current pool state and price
        (int24 currentTick, uint160 sqrtPriceX96) = _getCurrentPoolState();
        uint256 ethAmount = msg.value;

        // Calculate amount of WBTC needed based on current price
        uint256 wbtcAmount = _calculateWBTCAmount(ethAmount, sqrtPriceX96);

        // Swap ETH for WBTC
        bytes memory swapData = abi.encode(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: false, // ETH to WBTC
                amountSpecified: int256(ethAmount / 2),
                sqrtPriceLimitX96: _getMinSqrtPrice(sqrtPriceX96)
            })
        );

        poolManager.unlock(swapData);

        // Add liquidity with both WBTC and remaining ETH
        (int24 tickLower, int24 tickUpper) = _calculateOptimalTickRange(currentTick);

        bytes memory liquidityData = abi.encode(
            poolKey,
            IPoolManager.ModifyPositionParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(wbtcAmount)
            })
        );

        poolManager.unlock(liquidityData);

        emit LiquidityAdded(positionId, wbtcAmount, ethAmount);
    }

    /**
     * @notice Remove liquidity and get ETH
     * @param ethNeeded Amount of ETH needed
     */
    function removeLiquidityForEth(uint128 ethNeeded) external nonReentrant {
        require(ethNeeded > 0, "Zero ETH needed");

        // Calculate extra amount to remove for slippage and fees
        uint256 totalEthToRemove = (ethNeeded * (10000 + SLIPPAGE_TOLERANCE)) / 10000;

        // Remove liquidity
        bytes memory data = abi.encode(
            poolKey,
            IPoolManager.ModifyPositionParams({
                tickLower: type(int24).min,
                tickUpper: type(int24).max,
                liquidityDelta: -int256(totalEthToRemove)
            })
        );

        poolManager.unlock(data);

        // Swap WBTC back to ETH if needed
        if (wbtcToken.balanceOf(address(this)) > 0) {
            bytes memory swapData = abi.encode(
                poolKey,
                IPoolManager.SwapParams({
                    zeroForOne: true, // WBTC to ETH
                    amountSpecified: int256(wbtcToken.balanceOf(address(this))),
                    sqrtPriceLimitX96: _getMaxSqrtPrice(sqrtPriceX96)
                })
            );

            poolManager.unlock(swapData);
        }

        // Send exact ETH amount to user
        (bool success,) = msg.sender.call{value: ethNeeded}("");
        require(success, "ETH transfer failed");

        // Send any excess ETH to fee recipient
        uint256 excess = address(this).balance;
        if (excess > 0) {
            (success,) = feeRecipient.call{value: excess}("");
            require(success, "Fee transfer failed");
        }

        emit LiquidityRemoved(positionId, 0, ethNeeded);
    }

    /**
     * @notice Calculate optimal tick range based on current tick
     */
    function _calculateOptimalTickRange(
        int24 currentTick
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        int24 tickRange = int24(uint24(RANGE_WIDTH) * TICK_SPACING / 100);
        
        tickLower = currentTick - tickRange;
        tickUpper = currentTick + tickRange;
        
        tickLower = (tickLower / TICK_SPACING) * TICK_SPACING;
        tickUpper = (tickUpper / TICK_SPACING) * TICK_SPACING;
        
        if (tickUpper - tickLower < TICK_SPACING * 2) {
            tickLower = currentTick - TICK_SPACING;
            tickUpper = currentTick + TICK_SPACING;
        }
    }

    /**
     * @notice Get current pool state
     */
    function _getCurrentPoolState() internal view returns (
        int24 tick,
        uint160 sqrtPriceX96
    ) {
        PoolId poolId = poolManager.getPoolId(poolKey);
        (sqrtPriceX96, tick, , , ) = poolManager.getSlot0(poolId);
    }

    /**
     * @notice Calculate WBTC amount needed for balanced liquidity
     */
    function _calculateWBTCAmount(
        uint256 ethAmount,
        uint160 sqrtPriceX96
    ) internal pure returns (uint256) {
        // Calculate based on Uniswap v4 price formula
        uint256 price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) >> 192;
        return (ethAmount * price) / 1e18;
    }

    /**
     * @notice Get minimum sqrt price for slippage protection
     */
    function _getMinSqrtPrice(uint160 sqrtPriceX96) internal pure returns (uint160) {
        return sqrtPriceX96 - (sqrtPriceX96 * uint160(SLIPPAGE_TOLERANCE) / 10000);
    }

    /**
     * @notice Get maximum sqrt price for slippage protection
     */
    function _getMaxSqrtPrice(uint160 sqrtPriceX96) internal pure returns (uint160) {
        return sqrtPriceX96 + (sqrtPriceX96 * uint160(SLIPPAGE_TOLERANCE) / 10000);
    }

    // ========== Admin Functions ==========

    /**
     * @notice Update the fee recipient address
     * @param _newRecipient New fee recipient address
     */
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid recipient");
        feeRecipient = _newRecipient;
    }

    /**
     * @notice Allow owner to withdraw any leftover WBTC
     * @param amount Amount of WBTC to withdraw
     */
    function withdrawWBTC(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(amount <= wbtcToken.balanceOf(address(this)), "Insufficient balance");
        wbtcToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Allow owner to withdraw any leftover ETH
     * @param amount Amount of ETH to withdraw
     */
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
