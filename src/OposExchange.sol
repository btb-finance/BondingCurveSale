// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}

interface IBurnable {
    function burn(uint256 amount) external;
}

contract OPOSExchange is ReentrancyGuard, Ownable {
    address public tokenAddress;
    IERC20 public token;
 
    address public usdcTokenAddress;
    IERC20 public usdc;
 
    uint256 public feePercentage = 1;
    uint256 public startingPrice = 1e16;
 
    bool public playingDead;
    
    mapping(address => bool) public isNightwalker;

    event OpossumCaught(address indexed buyer, uint256 tokensBought, uint256 usdcSpent);
    event OpossumEscaped(address indexed seller, uint256 tokensSold, uint256 usdcReceived);
    event NewTrickLearned(uint256 oldFee, uint256 newFee);

    constructor(address _tokenAddress, address _usdcTokenAddress) Ownable(msg.sender) {
        tokenAddress = _tokenAddress;
        token = IERC20(_tokenAddress);
        usdcTokenAddress = _usdcTokenAddress;
        usdc = IERC20(_usdcTokenAddress);
        playingDead = false;
    }
 
    modifier notPlayingDead() {
        require(!playingDead, "Opossum is playing dead");
        _;
    }
 
    function countWildOpossums() private view returns (uint256) {  
        return token.totalSupply();
    }
 
    function raidTheTrash(address _token, uint256 _amount) external onlyOwner {  
        require(IERC20(_token).transfer(owner(), _amount), "No food in trash");
    }
 
    function stealShinyCoins(uint256 _amount) external onlyOwner {  
        require(usdc.transfer(owner(), _amount), "No coins found");
    }
 
    function howManyOpossums(uint256 usdcAmount) external view returns (uint256) {  
        uint256 currentUsdcBalance = usdc.balanceOf(address(this));
        uint256 price = getOpossumsPerCoin(currentUsdcBalance, countWildOpossums());
        uint256 fee = isNightwalker[msg.sender] ? 0 : feePercentage;
        return (usdcAmount * (10000 - fee) * 1e18) / (10000 * price);
    }
 
    function howManyCoins(uint256 tokensAmount) external view returns (uint256) {  
        uint256 currentUsdcBalance = usdc.balanceOf(address(this));
        uint256 price = getOpossumsPerCoin(currentUsdcBalance, countWildOpossums());
        uint256 fee = isNightwalker[msg.sender] ? 0 : feePercentage;
        return (tokensAmount * price * (10000 - fee)) / (10000 * 1e18);
    }
 
    function grantNightVision(address user, bool excluded) external onlyOwner {  
        isNightwalker[user] = excluded;
    }
 
    function playDead(bool _playingDead) external onlyOwner {  
        playingDead = _playingDead;
    }
 
    function teachNewTrick(uint256 _feePercentage) external onlyOwner {  
        require(_feePercentage <= 1000, "Too many tricks");
        uint256 oldFee = feePercentage;
        feePercentage = _feePercentage;
        emit NewTrickLearned(oldFee, _feePercentage);
    }
 
    function catchOpossum(uint256 usdcAmount) external notPlayingDead nonReentrant {  
        require(usdcAmount > 0, "Need more food");
 
        uint256 tokensToBuy = this.howManyOpossums(usdcAmount);
        require(tokensToBuy > 0, "Not enough food for opossums");
 
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "Food theft failed");
 
        if (!isNightwalker[msg.sender]) {
            uint256 fee = (usdcAmount * feePercentage) / 10000;
            require(usdc.transfer(owner(), fee), "Failed to pay zookeeper");
        }
 
        // Mint new tokens instead of transferring
        IMintable(tokenAddress).mint(msg.sender, tokensToBuy);
 
        emit OpossumCaught(msg.sender, tokensToBuy, usdcAmount);
    }
 
    function releaseOpossum(uint256 tokensToSell) external notPlayingDead nonReentrant {  
        require(tokensToSell > 0, "No opossums to release");
 
        uint256 currentUsdcBalance = usdc.balanceOf(address(this));
        uint256 price = getOpossumsPerCoin(currentUsdcBalance, countWildOpossums());
        uint256 fee = isNightwalker[msg.sender] ? 0 : feePercentage;
        uint256 usdcToReceive = (tokensToSell * price * (10000 - fee)) / (10000 * 1e18);
 
        require(usdcToReceive > 0, "Not enough opossums to release");
        require(usdcToReceive <= currentUsdcBalance, "Not enough coins in the zoo");
 
        require(token.transferFrom(msg.sender, address(this), tokensToSell), "Failed to catch");
        IBurnable(tokenAddress).burn(tokensToSell);
        
        require(usdc.transfer(msg.sender, usdcToReceive), "No reward received");
 
        if (!isNightwalker[msg.sender]) {
            uint256 feeAmount = (usdcToReceive * feePercentage) / (10000 - feePercentage);
            require(usdc.transfer(owner(), feeAmount), "Failed to pay zookeeper");
        }
 
        emit OpossumEscaped(msg.sender, tokensToSell, usdcToReceive);
    }
 
    function getOpossumsPerCoin(uint256 totalUsdcInContract, uint256 _totalTokensSupply) public view returns (uint256) {  
        if (totalUsdcInContract == 0 || _totalTokensSupply == 0) {
            return startingPrice;
        }
        return (totalUsdcInContract * 1e18) / _totalTokensSupply;
    }
 
    function askZookeeper() public view returns (uint256) {  
        uint256 currentUsdcBalance = usdc.balanceOf(address(this));
        uint256 totalTokens = token.totalSupply();
        if (currentUsdcBalance == 0 || totalTokens == 0) {
            return startingPrice;
        }
        return (currentUsdcBalance * 1e18) / totalTokens;
    }
}
