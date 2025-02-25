// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract BTBExchangeV2 is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public immutable token;
    IERC20 public immutable usdc;
    address public adminAddress;
    uint256 public constant PRECISION = 1e6;
    uint256 public constant TOKEN_PRECISION = 1e18;
    uint256 public totalTokensSold;
    uint256 public totalUsdcContributed;
    uint256 public usdcReserve;
    uint256 public buyFee = 30;
    uint256 public sellFee = 30;
    uint256 public constant ADMIN_FEE_PORTION = 10;
    uint256 public constant PRICE_CONTRIBUTION_PORTION = 20;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public lastTradeBlock;
    uint256 public constant MIN_PRICE = 10000;
    bool public emergencyMode;
    uint256 public priceMultiplier = PRECISION;
    uint256 public constant SELL_PRICE_INCREASE = 20;

    event TokensPurchased(address indexed buyer, uint256 usdcAmount, uint256 tokenAmount, uint256 priceContribution, uint256 adminFee);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 usdcAmount, uint256 priceContribution, uint256 adminFee, uint256 newPriceMultiplier);
    event FeesUpdated(uint256 newBuyFee, uint256 newSellFee);
    event AdminAddressUpdated(address indexed newAdmin);
    event TokensWithdrawn(address indexed token, uint256 amount);
    event ReserveUpdated(uint256 newReserve);
    event EmergencyModeSet(bool activated);

    error SameBlockTrade();
    error PriceBelowMinimum();
    error ZeroCirculatingSupply();
    error InsufficientReserve();
    error EmergencyModeActive();
    error InvalidAmount();
    error TransferFailed();

    modifier notEmergency() {
        if (emergencyMode) revert EmergencyModeActive();
        _;
    }

    constructor(
        address _token,
        address _usdc,
        address _adminAddress
    ) {
        require(_token != address(0), "Invalid token address");
        require(_usdc != address(0), "Invalid USDC address");
        require(_adminAddress != address(0), "Invalid admin address");

        token = IERC20(_token);
        usdc = IERC20(_usdc);
        adminAddress = _adminAddress;
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 contractTokenBalance = token.balanceOf(address(this));
        
        uint256 circulatingSupply = totalSupply > contractTokenBalance ? 
                                   totalSupply - contractTokenBalance : 0;
        
        if (circulatingSupply == 0) {
            return MIN_PRICE;
        }
        
        uint256 basePrice = (totalUsdcContributed * PRECISION * TOKEN_PRECISION) / circulatingSupply;
        uint256 adjustedPrice = (basePrice * priceMultiplier) / PRECISION;
        
        return adjustedPrice < MIN_PRICE ? MIN_PRICE : adjustedPrice;
    }

    function buyTokens(uint256 usdcAmount) external nonReentrant whenNotPaused notEmergency {
        if (usdcAmount == 0) revert InvalidAmount();
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        uint256 totalFeeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * ADMIN_FEE_PORTION) / FEE_PRECISION;
        uint256 priceContributionAmount = (usdcAmount * PRICE_CONTRIBUTION_PORTION) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        uint256 price = getCurrentPrice();
        uint256 tokenAmount = (usdcAfterFee * TOKEN_PRECISION) / price;
        
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");

        totalUsdcContributed += (usdcAmount - adminFeeAmount);
        usdcReserve += usdcAfterFee;
        totalTokensSold += tokenAmount;
        lastTradeBlock = block.number;

        bool success1 = token.transfer(msg.sender, tokenAmount);
        if (!success1) revert TransferFailed();
        
        bool success2 = usdc.transferFrom(msg.sender, address(this), usdcAfterFee + priceContributionAmount);
        if (!success2) revert TransferFailed();
        
        bool success3 = usdc.transferFrom(msg.sender, adminAddress, adminFeeAmount);
        if (!success3) revert TransferFailed();

        emit TokensPurchased(msg.sender, usdcAmount, tokenAmount, priceContributionAmount, adminFeeAmount);
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant whenNotPaused notEmergency {
        if (tokenAmount == 0) revert InvalidAmount();
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        uint256 price = getCurrentPrice();
        
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 totalFeeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * ADMIN_FEE_PORTION) / FEE_PRECISION;
        uint256 priceContributionAmount = (usdcAmount * PRICE_CONTRIBUTION_PORTION) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;

        if (usdcAfterFee > usdcReserve) revert InsufficientReserve();

        priceMultiplier = priceMultiplier + (priceMultiplier * SELL_PRICE_INCREASE / FEE_PRECISION);

        usdcReserve -= usdcAfterFee;
        totalTokensSold -= tokenAmount;
        lastTradeBlock = block.number;

        bool success1 = token.transferFrom(msg.sender, address(this), tokenAmount);
        if (!success1) revert TransferFailed();
        
        bool success2 = usdc.transfer(msg.sender, usdcAfterFee);
        if (!success2) revert TransferFailed();
        
        if (adminFeeAmount > 0) {
            bool success3 = usdc.transfer(adminAddress, adminFeeAmount);
            if (!success3) revert TransferFailed();
        }

        emit TokensSold(msg.sender, tokenAmount, usdcAfterFee, priceContributionAmount, adminFeeAmount, priceMultiplier);
    }

    function updateFees(uint256 newBuyFee, uint256 newSellFee) external onlyOwner {
        require(newBuyFee <= FEE_PRECISION, "Buy fee too high");
        require(newSellFee <= FEE_PRECISION, "Sell fee too high");
        buyFee = newBuyFee;
        sellFee = newSellFee;
        emit FeesUpdated(newBuyFee, newSellFee);
    }

    function updateAdminAddress(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Invalid admin address");
        adminAddress = newAdmin;
        emit AdminAddressUpdated(newAdmin);
    }

    function withdrawUsdc(uint256 amount) external onlyOwner {
        require(amount <= usdc.balanceOf(address(this)) - usdcReserve, "Cannot withdraw from reserves");
        usdc.safeTransfer(msg.sender, amount);
    }
    
    function withdrawToken(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(token)) {
            uint256 excessTokens = token.balanceOf(address(this)) - totalTokensSold;
            require(amount <= excessTokens, "Cannot withdraw from circulating supply");
        }
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(tokenAddress, amount);
    }
    
    function updateUsdcReserve() external onlyOwner {
        uint256 actualReserve = usdc.balanceOf(address(this));
        usdcReserve = actualReserve;
        emit ReserveUpdated(actualReserve);
    }

    function setEmergencyMode(bool activated) external onlyOwner {
        emergencyMode = activated;
        if (activated) {
            _pause();
        }
        emit EmergencyModeSet(activated);
    }

    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(usdc)) {
            require(amount <= usdc.balanceOf(address(this)) - usdcReserve, "Cannot withdraw from reserves");
        } else if (tokenAddress == address(token)) {
            uint256 excessTokens = token.balanceOf(address(this)) - totalTokensSold;
            require(amount <= excessTokens, "Cannot withdraw from circulating supply");
        }
        IERC20(tokenAddress).safeTransfer(owner(), amount);
        emit TokensWithdrawn(tokenAddress, amount);
    }

    function resetPriceMultiplier() external onlyOwner {
        priceMultiplier = PRECISION;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
