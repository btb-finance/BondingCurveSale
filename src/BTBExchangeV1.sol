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
    
    uint256 public usdcBorrowed;
    uint256 public buyFee = 30;
    uint256 public sellFee = 30;
    uint256 public adminFee = 10;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public lastTradeBlock;
    uint256 public constant MIN_PRICE = 10000;
    uint256 public constant MIN_EFFECTIVE_CIRCULATION = 1e16;
    uint256 public constant MAX_INITIAL_PRICE = 100000;

    event FeesUpdated(uint256 newBuyFee, uint256 newSellFee, uint256 newAdminFee);
    event AdminAddressUpdated(address indexed newAdmin);
    event TokensWithdrawn(address indexed token, uint256 amount);
    event UsdcBorrowed(uint256 amount, uint256 totalBorrowed);
    event UsdcRepaid(uint256 amount, uint256 remainingBorrowed);
    event TokensBought(address indexed buyer, uint256 usdcAmount, uint256 tokenAmount, uint256 totalFeePercent);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 usdcAmount, uint256 totalFeePercent);

    error SameBlockTrade();
    error PriceBelowMinimum();
    error InsufficientReserve();
    error InvalidAmount();
    error TransferFailed();

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

    function getTotalFee() public view returns (uint256) {
        return buyFee + adminFee;
    }

    function getSellTotalFee() public view returns (uint256) {
        return sellFee + adminFee;
    }

    function buyTokens(uint256 usdcAmount) external nonReentrant whenNotPaused {
        if (usdcAmount == 0) revert InvalidAmount();
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        uint256 platformFeeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        uint256 totalFeeAmount = platformFeeAmount + adminFeeAmount;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        uint256 price = getCurrentPrice();
        uint256 tokenAmount = (usdcAfterFee * TOKEN_PRECISION) / price;
        
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount - adminFeeAmount);
        usdc.safeTransferFrom(msg.sender, adminAddress, adminFeeAmount);
        
        lastTradeBlock = block.number;

        token.safeTransfer(msg.sender, tokenAmount);
        
        emit TokensBought(msg.sender, usdcAmount, tokenAmount, buyFee + adminFee);
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant whenNotPaused {
        if (tokenAmount == 0) revert InvalidAmount();
        if (block.number == lastTradeBlock) revert SameBlockTrade();

        uint256 price = getCurrentPrice();
        
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 platformFeeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        uint256 totalFeeAmount = platformFeeAmount + adminFeeAmount;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;

        if (usdcAfterFee + adminFeeAmount > usdc.balanceOf(address(this))) 
            revert InsufficientReserve();

        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        
        lastTradeBlock = block.number;
        
        usdc.safeTransfer(msg.sender, usdcAfterFee);
        usdc.safeTransfer(adminAddress, adminFeeAmount);
        
        emit TokensSold(msg.sender, tokenAmount, usdcAfterFee, sellFee + adminFee);
    }

    function updateFees(uint256 newBuyFee, uint256 newSellFee, uint256 newAdminFee) external onlyOwner {
        require(newBuyFee <= FEE_PRECISION, "Buy fee too high");
        require(newSellFee <= FEE_PRECISION, "Sell fee too high");
        require(newAdminFee <= FEE_PRECISION, "Admin fee too high");
        buyFee = newBuyFee;
        sellFee = newSellFee;
        adminFee = newAdminFee;
        emit FeesUpdated(newBuyFee, newSellFee, newAdminFee);
    }

    function updateAdminAddress(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Invalid admin address");
        adminAddress = newAdmin;
        emit AdminAddressUpdated(newAdmin);
    }

    function borrowUsdc(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
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
        IERC20(tokenAddress).safeTransfer(owner(), amount);
        emit TokensWithdrawn(tokenAddress, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    
    function quoteTokensForUsdc(uint256 usdcAmount) external view returns (uint256) {
        if (usdcAmount == 0) return 0;
        
        uint256 platformFeeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        uint256 totalFeeAmount = platformFeeAmount + adminFeeAmount;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        uint256 price = getCurrentPrice();
        uint256 tokenAmount = (usdcAfterFee * TOKEN_PRECISION) / price;
        
        return tokenAmount;
    }
    
    function quoteUsdcForTokens(uint256 tokenAmount) external view returns (uint256) {
        if (tokenAmount == 0) return 0;
        
        uint256 price = getCurrentPrice();
        
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 platformFeeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        uint256 totalFeeAmount = platformFeeAmount + adminFeeAmount;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        return usdcAfterFee;
    }
}