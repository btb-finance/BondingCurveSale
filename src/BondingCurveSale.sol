// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/contracts/types/PoolId.sol";
import "@uniswap/v4-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v4-periphery/contracts/interfaces/IHooks.sol";

import "./BondingCurveMath.sol";
import "./interfaces/IUniswapV4PositionManager.sol";

/**
 * @title BondingCurveSale
 * @notice Implements a 1% step bonding curve for the OPOSSUM token
 *         with integrated Uniswap V4 liquidity management on ETH/WBTC.
 */
contract BondingCurveSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PoolId for IPoolManager;

    // ====== Token & Price Settings ======
    IERC20 public immutable saleToken;  // OPOSSUM token
    uint256 public basePrice;           // P0 in wei (ETH), initially 0.000001 ETH
    uint256 public netTokensSold;       // "N" - net number of tokens sold via bonding curve

    // ====== Fees ======
    uint256 public constant BUY_FEE_BASIS_POINTS = 500;   // 5%
    uint256 public constant SELL_FEE_BASIS_POINTS = 1000; // 10%
    address public feeRecipient;                          // collects fees

    // ====== Uniswap V4 Integration ======
    INonfungiblePositionManager public positionManager;
    IPoolManager public poolManager;
    address public wbtcToken;
    uint24 public poolFee;
    uint256 public positionTokenId;
    
    // Liquidity range constants
    int24 public constant TICK_SPACING = 60;
    uint24 public constant RANGE_WIDTH = 500; // ±5% range in basis points

    // ====== Events ======
    event Buy(address indexed buyer, uint256 tokenAmount, uint256 ethSpent);
    event Sell(address indexed seller, uint256 tokenAmount, uint256 ethReceived);
    event FeeRecipientUpdated(address indexed newRecipient);
    event LiquidityPositionUpdated(
        uint256 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );
    event LiquidityRemoved(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    constructor(
        address _saleToken,
        address _feeRecipient,
        address _positionManager,
        address _poolManager,
        address _wbtcToken,
        uint24 _poolFee
    ) {
        require(_saleToken != address(0), "Invalid token");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_positionManager != address(0), "Invalid position manager");
        require(_poolManager != address(0), "Invalid pool manager");
        require(_wbtcToken != address(0), "Invalid WBTC address");

        saleToken = IERC20(_saleToken);
        basePrice = 1e12; // 0.000001 ETH in wei
        feeRecipient = _feeRecipient;
        positionManager = INonfungiblePositionManager(_positionManager);
        poolManager = IPoolManager(_poolManager);
        wbtcToken = _wbtcToken;
        poolFee = _poolFee;
    }

    // ========= BUY FUNCTION =========
    /**
     * @notice Buy `x` tokens from the bonding curve, paying in ETH.
     * @param x Number of tokens to buy (integer, no decimals).
     */
    function buy(uint256 x) external payable nonReentrant {
        require(x > 0, "Invalid amount");

        // 1) Compute raw cost from library
        uint256 rawCost = BondingCurveMath.buyCost(basePrice, netTokensSold, x);
        // 2) Compute buy fee
        uint256 fee = (rawCost * BUY_FEE_BASIS_POINTS) / BondingCurveMath.FEE_DENOM;
        uint256 totalCost = rawCost + fee;

        require(msg.value >= totalCost, "Insufficient ETH sent");

        // 3) Transfer fee to recipient
        _safeTransferETH(feeRecipient, fee);

        // 4) Transfer tokens to buyer
        //    Make sure the contract has enough tokens to sell
        require(saleToken.balanceOf(address(this)) >= x, "Not enough tokens in contract");
        saleToken.safeTransfer(msg.sender, x);

        // 5) Update netTokensSold
        netTokensSold += x;

        // 6) Possibly add liquidity to Uniswap with leftover ETH
        uint256 leftoverETH = msg.value - totalCost;
        if (leftoverETH > 0) {
            // You could either refund leftover or use a portion for liquidity. 
            // We'll just refund the entire leftover to user for simplicity.
            _safeTransferETH(msg.sender, leftoverETH);
        }

        // Optionally, call internal function to re-center and add liquidity 
        // with some portion of rawCost. Example only, commented out:
        // _addOrRecenterLiquidity(rawCost / 2);

        emit Buy(msg.sender, x, totalCost);
    }

    // ========= SELL FUNCTION =========
    /**
     * @notice Sell `x` tokens back to the bonding curve, receiving ETH.
     * @param x Number of tokens to sell
     */
    function sell(uint256 x) external nonReentrant {
        require(x > 0, "Invalid amount");

        // 1) Calculate raw payout
        uint256 rawPayout = BondingCurveMath.sellPayout(basePrice, netTokensSold, x);
        // 2) Sell fee
        uint256 fee = (rawPayout * SELL_FEE_BASIS_POINTS) / BondingCurveMath.FEE_DENOM;
        uint256 finalPayout = rawPayout - fee;

        // 3) Transfer fee to feeRecipient
        //    We'll pay fee from the contract's ETH reserves, so we need enough ETH in contract.
        //    If we don't have enough ETH, we might remove liquidity from Uniswap automatically.
        
        // Pull tokens from the user
        saleToken.safeTransferFrom(msg.sender, address(this), x);

        // Update netTokensSold
        // Because user is *selling* tokens back, netTokensSold decreases
        netTokensSold -= x;

        // Make sure we have enough ETH to pay finalPayout + fee. 
        // If not, we remove liquidity from Uniswap:
        _ensureETHBalance(finalPayout + fee);

        // Transfer the fee
        _safeTransferETH(feeRecipient, fee);

        // Transfer the final payout to the seller
        _safeTransferETH(msg.sender, finalPayout);

        // Optionally, re-center liquidity after each sell
        // _removeAndRecenterLiquidity();

        emit Sell(msg.sender, x, finalPayout);
    }

    // ========= UNISWAP V4 LIQUIDITY MANAGEMENT =========

    /**
     * @notice Ensures the contract has at least `amountNeeded` ETH. If not, 
     *         we remove some liquidity from Uniswap to cover the shortfall.
     * @dev In a real contract, you'd calculate how much liquidity to remove, 
     *      call decreaseLiquidity(), collect(), swap WBTC->ETH if needed, etc.
     */
    function _ensureETHBalance(uint256 amountNeeded) internal {
        uint256 ethBal = address(this).balance;
        if (ethBal < amountNeeded) {
            // remove partial liquidity from Uniswap, swap WBTC for ETH
            // For demonstration, this is a stub.
            // ...
        }
    }

    /**
     * @notice Adds or recenters liquidity in Uniswap V4 pool
     * @param ethAmount Amount of ETH to use for liquidity
     */
    function _addOrRecenterLiquidity(uint256 ethAmount) internal {
        require(ethAmount > 0, "Zero amount");
        
        // 1. Get current pool price and calculate range
        (int24 currentTick,,) = _getCurrentPoolState();
        (int24 tickLower, int24 tickUpper) = _calculateTickRange(currentTick);

        // 2. If we have an existing position, remove it first
        if (positionTokenId != 0) {
            _removeLiquidity(positionTokenId);
        }

        // 3. Calculate optimal token amounts
        (uint256 amount0Desired, uint256 amount1Desired) = _calculateOptimalAmounts(
            ethAmount,
            tickLower,
            tickUpper
        );

        // 4. Approve tokens if needed
        IERC20(wbtcToken).approve(address(positionManager), amount1Desired);

        // 5. Create new position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(this), // ETH
            token1: wbtcToken,
            fee: poolFee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0, // Add slippage protection in production
            amount1Min: 0, // Add slippage protection in production
            recipient: address(this),
            deadline: block.timestamp
        });

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = positionManager.mint{value: amount0Desired}(params);

        positionTokenId = tokenId;

        emit LiquidityPositionUpdated(tokenId, tickLower, tickUpper, liquidity);
    }

    /**
     * @notice Removes liquidity from a position
     * @param tokenId NFT position ID to remove liquidity from
     */
    function _removeLiquidity(uint256 tokenId) internal {
        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(tokenId);
        
        if (liquidity > 0) {
            // 1. Decrease liquidity
            INonfungiblePositionManager.DecreaseLiquidityParams memory params = 
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0, // Add slippage protection in production
                    amount1Min: 0, // Add slippage protection in production
                    deadline: block.timestamp
                });

            (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(params);

            // 2. Collect all tokens
            INonfungiblePositionManager.CollectParams memory collectParams = 
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                });

            positionManager.collect(collectParams);

            emit LiquidityRemoved(tokenId, liquidity, amount0, amount1);
        }
    }

    /**
     * @notice Gets current pool state
     * @return tick Current tick
     * @return sqrtPriceX96 Current sqrt price
     * @return liquidity Current pool liquidity
     */
    function _getCurrentPoolState() internal view returns (
        int24 tick,
        uint160 sqrtPriceX96,
        uint128 liquidity
    ) {
        PoolId poolId = poolManager.getPoolId(
            address(this), // ETH
            wbtcToken,
            poolFee
        );
        
        (sqrtPriceX96, tick, liquidity, , ) = poolManager.getSlot0(poolId);
    }

    /**
     * @notice Calculates tick range for ±5% around current tick
     */
    function _calculateTickRange(int24 currentTick) internal pure returns (
        int24 tickLower,
        int24 tickUpper
    ) {
        int24 tickSpacing = TICK_SPACING;
        int24 tickRange = int24(uint24(RANGE_WIDTH) * tickSpacing / 100);
        
        tickLower = currentTick - tickRange;
        tickUpper = currentTick + tickRange;
        
        // Round to nearest tick spacing
        tickLower = (tickLower / tickSpacing) * tickSpacing;
        tickUpper = (tickUpper / tickSpacing) * tickSpacing;
    }

    /**
     * @notice Calculates optimal token amounts for the liquidity range
     */
    function _calculateOptimalAmounts(
        uint256 ethAmount,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256 amount0Desired, uint256 amount1Desired) {
        // In production, implement sophisticated calculation based on:
        // 1. Current price
        // 2. Target price range
        // 3. Desired concentration of liquidity
        
        // For now, just split 50/50
        amount0Desired = ethAmount;
        amount1Desired = ethAmount; // This should be adjusted based on WBTC/ETH price
    }

    // ========== Admin Functions ==========

    function setFeeRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Zero address");
        feeRecipient = _recipient;
        emit FeeRecipientUpdated(_recipient);
    }

    function setBasePrice(uint256 _basePrice) external onlyOwner {
        basePrice = _basePrice;
    }

    function withdrawTokens(address _to, uint256 _amount) external onlyOwner {
        saleToken.safeTransfer(_to, _amount);
    }

    function withdrawETH(address _to, uint256 _amount) external onlyOwner {
        _safeTransferETH(_to, _amount);
    }

    // ========== Internal Helpers ==========

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "ETH transfer failed");
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
