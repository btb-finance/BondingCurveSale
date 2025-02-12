// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BondingCurveMath.sol";
import "./LiquidityManager.sol";

/**
 * @title BondingCurveSale
 * @notice Implements a 1% step bonding curve for the OPOSSUM token
 */
contract BondingCurveSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ====== Token & Price Settings ======
    IERC20 public immutable saleToken;  // OPOSSUM token
    uint256 public basePrice;           // P0 in wei (ETH), initially 0.000001 ETH
    uint256 public netTokensSold;       // "N" - net number of tokens sold via bonding curve

    // ====== Fees ======
    uint256 public constant BUY_FEE_BASIS_POINTS = 500;   // 5%
    uint256 public constant SELL_FEE_BASIS_POINTS = 1000; // 10%
    address public feeRecipient;                          // collects fees

    // ====== Liquidity Management ======
    LiquidityManager public liquidityManager;

    // ====== Events ======
    event Buy(address indexed buyer, uint256 tokenAmount, uint256 ethSpent);
    event Sell(address indexed seller, uint256 tokenAmount, uint256 ethReceived);
    event FeeRecipientUpdated(address indexed newRecipient);

    constructor(
        address _saleToken,
        address _feeRecipient,
        address _liquidityManager
    ) {
        require(_saleToken != address(0), "Invalid token");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_liquidityManager != address(0), "Invalid liquidity manager");

        saleToken = IERC20(_saleToken);
        basePrice = 1e12; // 0.000001 ETH in wei
        feeRecipient = _feeRecipient;
        liquidityManager = LiquidityManager(_liquidityManager);

        // Approve max tokens for liquidity manager
        saleToken.approve(_liquidityManager, type(uint256).max);
    }

    // ====== View Functions ======
    /**
     * @notice Calculate how many tokens you would receive for a given ETH amount
     * @param ethAmount Amount of ETH in wei
     * @return tokenAmount Amount of tokens you would receive
     */
    function calculateTokensForEth(uint256 ethAmount) public view returns (uint256 tokenAmount) {
        require(ethAmount > 0, "Zero ETH amount");
        
        // Remove buy fee from ETH amount
        uint256 ethAfterFee = (ethAmount * (10000 - BUY_FEE_BASIS_POINTS)) / 10000;
        
        // Calculate token amount using bonding curve
        uint256 currentPrice = BondingCurveMath.getCurrentPrice(basePrice, netTokensSold);
        tokenAmount = (ethAfterFee * 1e18) / currentPrice; // Scale by 1e18 for precision
    }

    /**
     * @notice Calculate how much ETH you would receive for selling tokens
     * @param tokenAmount Amount of tokens to sell
     * @return ethAmount Amount of ETH you would receive in wei
     */
    function calculateEthForTokens(uint256 tokenAmount) public view returns (uint256 ethAmount) {
        require(tokenAmount > 0, "Zero token amount");
        
        // Calculate raw ETH amount using bonding curve
        ethAmount = BondingCurveMath.sellPayout(basePrice, netTokensSold, tokenAmount);
        
        // Apply sell fee
        ethAmount = (ethAmount * (10000 - SELL_FEE_BASIS_POINTS)) / 10000;
    }

    /**
     * @notice Get current token price in ETH
     * @return price Current price in wei
     */
    function getCurrentPrice() public view returns (uint256 price) {
        return BondingCurveMath.getCurrentPrice(basePrice, netTokensSold);
    }

    // ====== Trading Functions ======
    /**
     * @notice Buy tokens with ETH
     */
    function buy() external payable nonReentrant {
        require(msg.value > 0, "Zero ETH sent");
        
        // Calculate token amount to receive
        uint256 tokenAmount = calculateTokensForEth(msg.value);
        require(tokenAmount > 0, "Zero tokens to receive");
        
        // Calculate fee
        uint256 feeAmount = (msg.value * BUY_FEE_BASIS_POINTS) / 10000;
        uint256 ethForLiquidity = msg.value - feeAmount;
        
        // Transfer fee
        _safeTransferETH(feeRecipient, feeAmount);
        
        // Update state
        netTokensSold += tokenAmount;
        
        // Transfer tokens to user
        saleToken.safeTransfer(msg.sender, tokenAmount);
        
        // Add all remaining ETH to liquidity
        liquidityManager.addLiquidity{value: ethForLiquidity}();
        
        emit Buy(msg.sender, tokenAmount, msg.value);
    }

    /**
     * @notice Sell tokens for ETH
     * @param tokenAmount Amount of tokens to sell
     */
    function sell(uint256 tokenAmount) external nonReentrant {
        require(tokenAmount > 0, "Zero token amount");
        
        // Calculate ETH payout
        uint256 ethPayout = calculateEthForTokens(tokenAmount);
        require(ethPayout > 0, "Zero ETH payout");
        
        // Update state before transfer
        netTokensSold -= tokenAmount;
        
        // Transfer tokens from seller
        saleToken.safeTransferFrom(msg.sender, address(this), tokenAmount);
        
        // Remove liquidity to get ETH
        liquidityManager.removeLiquidityForEth(uint128(ethPayout));
        
        emit Sell(msg.sender, tokenAmount, ethPayout);
    }

    // ========== Admin Functions ==========

    function setFeeRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient");
        feeRecipient = _recipient;
        emit FeeRecipientUpdated(_recipient);
    }

    /**
     * @notice Allow owner to withdraw any leftover OPOSSUM tokens
     * @param amount Amount of tokens to withdraw
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(amount <= saleToken.balanceOf(address(this)), "Insufficient balance");
        saleToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Allow owner to withdraw any leftover ETH
     * @param amount Amount of ETH to withdraw
     */
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(amount <= address(this).balance, "Insufficient balance");
        _safeTransferETH(msg.sender, amount);
    }

    /**
     * @notice Update the base price (P0) of the bonding curve
     * @param newBasePrice New base price in wei
     */
    function setBasePrice(uint256 newBasePrice) external onlyOwner {
        require(newBasePrice > 0, "Zero base price");
        basePrice = newBasePrice;
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{value: value}("");
        require(success, "ETH transfer failed");
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
