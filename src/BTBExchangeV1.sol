// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract BTBExchangeV1 is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public immutable token;
    IERC20 public immutable usdc;
    address public adminAddress;
    uint256 public constant PRECISION = 1e6;
    uint256 public constant TOKEN_PRECISION = 1e18;
    uint256 public totalTokensSold;
    
    uint256 public usdcBorrowed;
    uint256 public buyFee = 30;
    uint256 public sellFee = 30;
    uint256 public constant ADMIN_FEE_PORTION = 10;
    uint256 public constant PRICE_CONTRIBUTION_PORTION = 20;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public lastTradeBlock;
    uint256 public constant MIN_PRICE = 10000;
    uint256 public constant MIN_EFFECTIVE_CIRCULATION = 1e16;
    uint256 public constant MAX_INITIAL_PRICE = 100000;
    bool public emergencyMode;

    event FeesUpdated(uint256 newBuyFee, uint256 newSellFee);
    event AdminAddressUpdated(address indexed newAdmin);
    event TokensWithdrawn(address indexed token, uint256 amount);
    event EmergencyModeSet(bool activated);
    event UsdcBorrowed(uint256 amount, uint256 totalBorrowed);
    event UsdcRepaid(uint256 amount, uint256 remainingBorrowed);

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
        usdcBorrowed = 0;
        _transferOwnership(msg.sender);
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 contractTokenBalance = token.balanceOf(address(this));
        
        uint256 circulatingSupply = totalSupply > contractTokenBalance ? 
                                   totalSupply - contractTokenBalance : 0;
        
        if (circulatingSupply == 0) {
            return MIN_PRICE;
        }
        
        uint256 effectiveUsdcBalance = usdc.balanceOf(address(this)) + usdcBorrowed;
        
        uint256 effectiveCirculation = circulatingSupply;
        if (circulatingSupply < MIN_EFFECTIVE_CIRCULATION) {
            effectiveCirculation = MIN_EFFECTIVE_CIRCULATION;
        }
        
        uint256 calculatedPrice = (effectiveUsdcBalance * TOKEN_PRECISION) / effectiveCirculation;
        
        if (calculatedPrice < MIN_PRICE) {
            return MIN_PRICE;
        } else if (calculatedPrice > MAX_INITIAL_PRICE && circulatingSupply < MIN_EFFECTIVE_CIRCULATION * 10) {
            return MAX_INITIAL_PRICE;
        } else {
            return calculatedPrice;
        }
    }

    function getEffectiveUsdcBalance() public view returns (uint256) {
        return usdc.balanceOf(address(this)) + usdcBorrowed;
    }

    function getActualUsdcBalance() public view returns (uint256) {
        return usdc.balanceOf(address(this));
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
   
        bool success1 = usdc.transferFrom(msg.sender, address(this), usdcAfterFee + priceContributionAmount);
        if (!success1) revert TransferFailed();
        
        bool success2 = usdc.transferFrom(msg.sender, adminAddress, adminFeeAmount);
        if (!success2) revert TransferFailed();

        totalTokensSold += tokenAmount;
        lastTradeBlock = block.number;

        bool success3 = token.transfer(msg.sender, tokenAmount);
        if (!success3) revert TransferFailed();
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant whenNotPaused notEmergency {
        if (tokenAmount == 0) revert InvalidAmount();
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        uint256 price = getCurrentPrice();
        
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 totalFeeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * ADMIN_FEE_PORTION) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;

        uint256 totalUsdcNeeded = usdcAfterFee;
        if (adminFeeAmount > 0) {
            totalUsdcNeeded += adminFeeAmount;
        }
        
        if (totalUsdcNeeded > usdc.balanceOf(address(this))) revert InsufficientReserve();

        bool success1 = token.transferFrom(msg.sender, address(this), tokenAmount);
        if (!success1) revert TransferFailed();
        
        totalTokensSold -= tokenAmount;
        lastTradeBlock = block.number;
        
        bool success2 = usdc.transfer(msg.sender, usdcAfterFee);
        if (!success2) revert TransferFailed();
        
        if (adminFeeAmount > 0) {
            bool success3 = usdc.transfer(adminAddress, adminFeeAmount);
            if (!success3) revert TransferFailed();
        }
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

    function borrowUsdc(uint256 amount) external onlyOwner {
        uint256 availableToWithdraw = usdc.balanceOf(address(this));
        require(amount <= availableToWithdraw, "Cannot borrow from reserves");
        
        usdc.safeTransfer(msg.sender, amount);
        usdcBorrowed += amount;
        
        emit UsdcBorrowed(amount, usdcBorrowed);
    }
    
    function repayUsdc(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(usdcBorrowed >= amount, "Repayment exceeds borrowed amount");
        
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdcBorrowed -= amount;
        
        emit UsdcRepaid(amount, usdcBorrowed);
    }
    
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(usdc)) {
            uint256 minLiquidity = totalTokensSold * MIN_PRICE / TOKEN_PRECISION;
            require(usdc.balanceOf(address(this)) - amount >= minLiquidity, "Must maintain minimum liquidity");
        } else if (tokenAddress == address(token)) {
            uint256 excessTokens = token.balanceOf(address(this)) - totalTokensSold;
            require(amount <= excessTokens, "Cannot withdraw from circulating supply");
        }
        IERC20(tokenAddress).safeTransfer(owner(), amount);
        
        emit TokensWithdrawn(tokenAddress, amount);
    }

    function setEmergencyMode(bool activated) external onlyOwner {
        emergencyMode = activated;
        if (activated) {
            _pause();
        } else {
            _unpause();
        }
        emit EmergencyModeSet(activated);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        require(!emergencyMode, "Cannot unpause in emergency mode");
        _unpause();
    }
    
    function quoteTokensForUsdc(uint256 usdcAmount) external view returns (uint256) {
        if (usdcAmount == 0) return 0;
        
        uint256 totalFeeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        uint256 price = getCurrentPrice();
        uint256 tokenAmount = (usdcAfterFee * TOKEN_PRECISION) / price;
        
        return tokenAmount;
    }
    
    function quoteUsdcForTokens(uint256 tokenAmount) external view returns (uint256) {
        if (tokenAmount == 0) return 0;
        
        uint256 price = getCurrentPrice();
        
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 totalFeeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        return usdcAfterFee;
    }
}