// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BTBExchangeV1 is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // State variables
    IERC20 public immutable token;      // The token being sold
    IERC20 public immutable usdc;       // USDC stablecoin
    uint256 public constant PRECISION = 1e6;  // USDC uses 6 decimals
    uint256 public constant TOKEN_PRECISION = 1e18; // Token uses 18 decimals
    uint256 public totalTokensSold;     // Tracks tokens sold
    uint256 public totalUsdcRaised;     // Tracks total USDC ever received including fees
    uint256 public buyFee;              // Fee percentage for buying (in basis points, e.g., 100 = 1%)
    uint256 public sellFee;             // Fee percentage for selling (in basis points)
    uint256 public constant FEE_PRECISION = 10000;  // 100% = 10000 basis points
    uint256 public lastTradeBlock;      // Last block where a trade occurred
    uint256 public constant MIN_PRICE = 10000;  // Minimum price of 0.01 USDC (1e4 because USDC has 6 decimals)

    // Events
    event TokensPurchased(address indexed buyer, uint256 usdcAmount, uint256 tokenAmount, uint256 fee);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 usdcAmount, uint256 fee);
    event FeesUpdated(uint256 newBuyFee, uint256 newSellFee);

    // Custom errors
    error SameBlockTrade();
    error PriceBelowMinimum();
    error ZeroCirculatingSupply();

    constructor(
        address _token,
        address _usdc,
        uint256 _buyFee,
        uint256 _sellFee
    ) {
        require(_token != address(0), "Invalid token address");
        require(_usdc != address(0), "Invalid USDC address");
        require(_buyFee <= FEE_PRECISION, "Buy fee too high");
        require(_sellFee <= FEE_PRECISION, "Sell fee too high");

        token = IERC20(_token);
        usdc = IERC20(_usdc);
        buyFee = _buyFee;
        sellFee = _sellFee;
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 contractTokenBalance = token.balanceOf(address(this));
        
        if (totalSupply <= contractTokenBalance) {
            return MIN_PRICE; // Return minimum price of 0.01 USDC
        }
        
        uint256 circulatingSupply = totalSupply - contractTokenBalance;
        uint256 price = (totalUsdcRaised * PRECISION) / (circulatingSupply / TOKEN_PRECISION);
        
        return price < MIN_PRICE ? MIN_PRICE : price;
    }

    function buyTokens(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(usdcAmount > 0, "Must send USDC");
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        // Calculate fee and tokens
        uint256 feeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - feeAmount;
        
        // Calculate token amount accounting for decimals
        // usdcAfterFee has 6 decimals, price has 6 decimals
        // We want the result to have 18 decimals (TOKEN_PRECISION)
        uint256 tokenAmount = (usdcAfterFee * TOKEN_PRECISION) / getCurrentPrice();
        
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");

        // Update state
        totalUsdcRaised += usdcAmount;
        totalTokensSold += tokenAmount;
        lastTradeBlock = block.number;

        // Transfer tokens and USDC
        token.safeTransfer(msg.sender, tokenAmount);
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        emit TokensPurchased(msg.sender, usdcAmount, tokenAmount, feeAmount);
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant whenNotPaused {
        require(tokenAmount > 0, "Token amount must be > 0");
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        uint256 price = getCurrentPrice();
        
        // Calculate USDC amount accounting for decimals
        // tokenAmount has 18 decimals, price has 6 decimals
        // We want the result to have 6 decimals (PRECISION)
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 feeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - feeAmount;

        // Update state
        totalUsdcRaised -= usdcAmount;
        totalTokensSold -= tokenAmount;
        lastTradeBlock = block.number;

        // Transfer tokens and USDC
        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        usdc.safeTransfer(msg.sender, usdcAfterFee);

        emit TokensSold(msg.sender, tokenAmount, usdcAfterFee, feeAmount);
    }

    function updateFees(uint256 newBuyFee, uint256 newSellFee) external onlyOwner {
        require(newBuyFee <= FEE_PRECISION, "Buy fee too high");
        require(newSellFee <= FEE_PRECISION, "Sell fee too high");
        buyFee = newBuyFee;
        sellFee = newSellFee;
        emit FeesUpdated(newBuyFee, newSellFee);
    }

    function withdrawUsdc(uint256 amount) external onlyOwner {
        usdc.safeTransfer(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}