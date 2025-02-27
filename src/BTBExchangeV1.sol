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
    IERC20 public btbToken;
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

    uint256 public constant BASE_TOKEN_REQUIREMENT = 3000 * 1e18;
    
    mapping(address => uint256) public userTradeCounts;
    mapping(address => uint256) public userLastTradeTime;
    
    mapping(address => uint256) public btbDeposits;
    mapping(address => uint256) public lockedBTB;
    mapping(address => uint256) public lockReleaseTime;

    event FeesUpdated(uint256 newBuyFee, uint256 newSellFee, uint256 newAdminFee);
    event AdminAddressUpdated(address indexed newAdmin);
    event TokensWithdrawn(address indexed token, uint256 amount);
    event UsdcBorrowed(uint256 amount, uint256 totalBorrowed);
    event UsdcRepaid(uint256 amount, uint256 remainingBorrowed);
    event TokensBought(address indexed buyer, uint256 usdcAmount, uint256 tokenAmount, uint256 totalFeePercent);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 usdcAmount, uint256 totalFeePercent);
    event TradeCountUpdated(address indexed user, uint256 count);
    event TradeCountReset(address indexed user);
    event BTBTokenUpdated(address indexed newBTBToken);
    event BTBDeposited(address indexed user, uint256 amount);
    event BTBWithdrawn(address indexed user, uint256 amount);
    event BTBLocked(address indexed user, uint256 amount, uint256 releaseTime);
    event BTBUnlocked(address indexed user, uint256 amount);

    error SameBlockTrade();
    error PriceBelowMinimum();
    error InsufficientReserve();
    error InvalidAmount();
    error TransferFailed();
    error InsufficientTokenDeposit(uint256 required, uint256 actual);
    error BTBStillLocked(uint256 releaseTime);
    error InsufficientUnlockedBTB(uint256 requested, uint256 available);

    constructor(
        address _token,
        address _usdc,
        address _adminAddress,
        address _btbToken
    ) {
        require(_token != address(0), "Invalid token address");
        require(_usdc != address(0), "Invalid USDC address");
        require(_adminAddress != address(0), "Invalid admin address");
        require(_btbToken != address(0), "Invalid BTB token address");

        token = IERC20(_token);
        usdc = IERC20(_usdc);
        btbToken = IERC20(_btbToken);
        adminAddress = _adminAddress;
        usdcBorrowed = 0;
        _transferOwnership(msg.sender);
    }

    function depositBTB(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        
        btbToken.safeTransferFrom(msg.sender, address(this), amount);
        btbDeposits[msg.sender] += amount;
        
        emit BTBDeposited(msg.sender, amount);
    }
    
    function withdrawBTB(uint256 amount) external nonReentrant {
    require(amount > 0, "Amount must be greater than zero");
    
    uint256 availableAmount = getAvailableBTB(msg.sender);
    if (amount > availableAmount) revert InsufficientUnlockedBTB(amount, availableAmount);
    
    btbDeposits[msg.sender] -= amount;
    btbToken.safeTransfer(msg.sender, amount);
    
    emit BTBWithdrawn(msg.sender, amount);
   }
    function unlockBTB() external nonReentrant {
        if(block.timestamp < lockReleaseTime[msg.sender]) revert BTBStillLocked(lockReleaseTime[msg.sender]);
        
        uint256 amountToUnlock = lockedBTB[msg.sender];
        lockedBTB[msg.sender] = 0;
        
        emit BTBUnlocked(msg.sender, amountToUnlock);
    }

    function getCurrentDayStartTimestamp() public view returns (uint256) {
        uint256 currentTimestamp = block.timestamp;
        uint256 daysSinceEpoch = currentTimestamp / 86400;
        return daysSinceEpoch * 86400;
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

    function getUserTradeCount(address user) public view returns (uint256) {
        uint256 lastResetTime = getCurrentDayStartTimestamp();
        
        if (userLastTradeTime[user] < lastResetTime) {
            return 0;
        }
        
        return userTradeCounts[user];
    }

    function getRequiredTokens(uint256 tradeCount) public pure returns (uint256) {
        if (tradeCount == 0) {
            return BASE_TOKEN_REQUIREMENT;
        }
        
        uint256 requirement = BASE_TOKEN_REQUIREMENT;
        for (uint256 i = 0; i < tradeCount; i++) {
            requirement = requirement * 3;
        }
        
        return requirement;
    }

    function _updateUserTradeCount(address user) internal {
        uint256 lastResetTime = getCurrentDayStartTimestamp();
        
        if (userLastTradeTime[user] < lastResetTime) {
            userTradeCounts[user] = 1;
            emit TradeCountReset(user);
        } else {
            userTradeCounts[user] += 1;
        }
        
        userLastTradeTime[user] = block.timestamp;
        emit TradeCountUpdated(user, userTradeCounts[user]);
    }

    function getAvailableBTB(address user) public view returns (uint256) {
        uint256 currentDayStart = getCurrentDayStartTimestamp();
        
        if (lockReleaseTime[user] <= currentDayStart) {
            return btbDeposits[user];
        }
        
        return btbDeposits[user] - lockedBTB[user];
    }

    function _lockUserBTB(address user, uint256 amount) internal {
        lockedBTB[user] = amount;
        lockReleaseTime[user] = getCurrentDayStartTimestamp() + 86400;
        
        emit BTBLocked(user, amount, lockReleaseTime[user]);
    }

    function buyTokens(uint256 usdcAmount) external nonReentrant whenNotPaused {
        if (usdcAmount == 0) revert InvalidAmount();
        if (block.number == lastTradeBlock) revert SameBlockTrade();
        
        uint256 tradeCount = getUserTradeCount(msg.sender);
        uint256 requiredBTB = getRequiredTokens(tradeCount);
        
        if (btbDeposits[msg.sender] < requiredBTB) {
            revert InsufficientTokenDeposit(requiredBTB, btbDeposits[msg.sender]);
        }

        uint256 platformFeeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        uint256 totalFeeAmount = platformFeeAmount + adminFeeAmount;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        uint256 price = getCurrentPrice();
        uint256 tokenAmount = (usdcAfterFee * TOKEN_PRECISION) / price;
        
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount - adminFeeAmount);
        usdc.safeTransferFrom(msg.sender, adminAddress, adminFeeAmount);
        
        _updateUserTradeCount(msg.sender);
        _lockUserBTB(msg.sender, requiredBTB);
        lastTradeBlock = block.number;

        token.safeTransfer(msg.sender, tokenAmount);
        
        emit TokensBought(msg.sender, usdcAmount, tokenAmount, buyFee + adminFee);
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant whenNotPaused {
        if (tokenAmount == 0) revert InvalidAmount();
        if (block.number == lastTradeBlock) revert SameBlockTrade();
        
        uint256 tradeCount = getUserTradeCount(msg.sender);
        uint256 requiredBTB = getRequiredTokens(tradeCount);
        
        if (btbDeposits[msg.sender] < requiredBTB) {
            revert InsufficientTokenDeposit(requiredBTB, btbDeposits[msg.sender]);
        }

        uint256 price = getCurrentPrice();
        
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 platformFeeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        uint256 adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        uint256 totalFeeAmount = platformFeeAmount + adminFeeAmount;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;

        if (usdcAfterFee + adminFeeAmount > usdc.balanceOf(address(this))) 
            revert InsufficientReserve();

        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        
        _updateUserTradeCount(msg.sender);
        _lockUserBTB(msg.sender, requiredBTB);
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

    function updateBTBToken(address newBTBToken) external onlyOwner {
        require(newBTBToken != address(0), "Invalid BTB token address");
        btbToken = IERC20(newBTBToken);
        emit BTBTokenUpdated(newBTBToken);
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
    
    function quoteTokensForUsdc(uint256 usdcAmount) external view returns (uint256 tokenAmount, uint256 adminFeeAmount, uint256 platformFeeAmount, uint256 totalFeeAmount) {
        if (usdcAmount == 0) return (0, 0, 0, 0);
        
        platformFeeAmount = (usdcAmount * buyFee) / FEE_PRECISION;
        adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        totalFeeAmount = platformFeeAmount + adminFeeAmount;
        uint256 usdcAfterFee = usdcAmount - totalFeeAmount;
        
        uint256 price = getCurrentPrice();
        tokenAmount = (usdcAfterFee * TOKEN_PRECISION) / price;
        
        return (tokenAmount, adminFeeAmount, platformFeeAmount, totalFeeAmount);
    }
    
    function quoteUsdcForTokens(uint256 tokenAmount) external view returns (uint256 usdcAfterFee, uint256 adminFeeAmount, uint256 platformFeeAmount, uint256 totalFeeAmount) {
        if (tokenAmount == 0) return (0, 0, 0, 0);
        
        uint256 price = getCurrentPrice();
        
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        platformFeeAmount = (usdcAmount * sellFee) / FEE_PRECISION;
        adminFeeAmount = (usdcAmount * adminFee) / FEE_PRECISION;
        totalFeeAmount = platformFeeAmount + adminFeeAmount;
        usdcAfterFee = usdcAmount - totalFeeAmount;
        
        return (usdcAfterFee, adminFeeAmount, platformFeeAmount, totalFeeAmount);
    }
    
    function getNextTradeRequirement(address user) external view returns (uint256) {
        uint256 tradeCount = getUserTradeCount(user);
        return getRequiredTokens(tradeCount);
    }
    
    function getNextResetTime() external view returns (uint256) {
        return getCurrentDayStartTimestamp() + 86400;
    }
    
    function getBTBLockReleaseTime(address user) external view returns (uint256) {
        return lockReleaseTime[user];
    }
    
    function getUserBTBStatus(address user) external view returns (
        uint256 totalDeposited,
        uint256 lockedAmount,
        uint256 availableAmount,
        uint256 lockReleaseTimestamp
    ) {
        return (
            btbDeposits[user],
            lockedBTB[user],
            btbDeposits[user] - lockedBTB[user],
            lockReleaseTime[user]
        );
    }
}