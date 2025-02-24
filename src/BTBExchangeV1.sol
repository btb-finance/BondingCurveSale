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
    uint256 public totalTokensSold;     // Tracks tokens sold
    uint256 public totalUsdcRaised;     // Tracks total USDC ever received including fees
    uint256 public buyFee;              // Fee percentage for buying (in basis points, e.g., 100 = 1%)
    uint256 public sellFee;             // Fee percentage for selling (in basis points)
    uint256 public constant FEE_PRECISION = 10000;  // 100% = 10000 basis points
    uint256 public lastTradeBlock;      // Last block where a trade occurred
    uint256 public constant MIN_PRICE = PRECISION;  // Minimum price of 1 USDC

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

    // Price = (Total USDC raised historically) / (Total Supply - Contract's Token Balance)
    function getCurrentPrice() public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 contractTokenBalance = token.balanceOf(address(this));
        
        if (totalSupply <= contractTokenBalance) {
            return MIN_PRICE; // Return minimum price if no tokens in circulation
        }
        
        uint256 circulatingSupply = totalSupply - contractTokenBalance;
        uint256 price = (totalUsdcRaised * PRECISION) / circulatingSupply;
        
        return price < MIN_PRICE ? MIN_PRICE : price;
    }

    function getTokenAmount(uint256 usdcAmount) public view returns (uint256) {
        require(usdcAmount > 0, "USDC amount must be > 0");
        uint256 price = getCurrentPrice();
        uint256 feeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - feeAmount;
        return (usdcAfterFee * PRECISION) / price;
    }

    function getUsdcAmount(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Token amount must be > 0");
        uint256 price = getCurrentPrice();
        uint256 usdcBeforeFee = (tokenAmount * price) / PRECISION;
        uint256 feeAmount = (usdcBeforeFee * sellFee) / FEE_PRECISION;
        return usdcBeforeFee - feeAmount;
    }

    function getTotalSupplyPrice() public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 circulatingSupply = totalSupply - contractBalance;
        uint256 price = getCurrentPrice();
        return (circulatingSupply * price) / PRECISION;
    }

    function buyTokens(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(usdcAmount > 0, "Must send USDC");
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        // Calculate fee and tokens
        uint256 feeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - feeAmount;
        uint256 tokenAmount = (usdcAfterFee * PRECISION) / getCurrentPrice();
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");

        // Update state
        totalTokensSold += tokenAmount;
        totalUsdcRaised += usdcAmount; // Include full amount with fee
        lastTradeBlock = block.number;

        // Transfer USDC and tokens
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        token.safeTransfer(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, usdcAmount, tokenAmount, feeAmount);
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant whenNotPaused {
        require(tokenAmount > 0, "Token amount must be > 0");
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        // Calculate USDC amount and fee
        uint256 price = getCurrentPrice();
        uint256 usdcBeforeFee = (tokenAmount * price) / PRECISION;
        uint256 feeAmount = (usdcBeforeFee * sellFee) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcBeforeFee - feeAmount;
        require(usdc.balanceOf(address(this)) >= usdcAfterFee, "Insufficient USDC in contract");

        // Update state
        totalTokensSold -= tokenAmount;
        lastTradeBlock = block.number;

        // Transfer tokens and USDC
        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        usdc.safeTransfer(msg.sender, usdcAfterFee);

        emit TokensSold(msg.sender, tokenAmount, usdcAfterFee, feeAmount);
    }

    function updateFees(uint256 _buyFee, uint256 _sellFee) external onlyOwner {
        require(_buyFee <= FEE_PRECISION, "Buy fee too high");
        require(_sellFee <= FEE_PRECISION, "Sell fee too high");
        buyFee = _buyFee;
        sellFee = _sellFee;
        emit FeesUpdated(_buyFee, _sellFee);
    }

    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        token.safeTransfer(msg.sender, amount);
    }

    function withdrawUsdc(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        usdc.safeTransfer(msg.sender, amount);
    }

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}