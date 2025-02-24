// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OposExchange is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // State variables
    IERC20 public immutable token;
    uint256 public constant PRECISION = 1e18;
    uint256 public initialPrice;
    uint256 public slope;
    uint256 public totalTokensSold;
    uint256 public totalEthRaised;

    // Events
    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount);
    event PriceParamsUpdated(uint256 newInitialPrice, uint256 newSlope);

    constructor(
        address _token,
        uint256 _initialPrice,
        uint256 _slope
    ) {
        require(_token != address(0), "Invalid token address");
        require(_initialPrice > 0, "Initial price must be > 0");
        require(_slope > 0, "Slope must be > 0");

        token = IERC20(_token);
        initialPrice = _initialPrice;
        slope = _slope;
    }

    /**
     * @notice Calculate current token price based on supply
     * @return Current token price
     */
    function getCurrentPrice() public view returns (uint256) {
        return initialPrice + (totalTokensSold * slope) / PRECISION;
    }

    /**
     * @notice Calculate token amount for given ETH amount
     * @param ethAmount Amount of ETH to spend
     * @return Token amount to receive
     */
    function getTokenAmount(uint256 ethAmount) public view returns (uint256) {
        require(ethAmount > 0, "ETH amount must be > 0");
        uint256 price = getCurrentPrice();
        return (ethAmount * PRECISION) / price;
    }

    /**
     * @notice Calculate ETH amount for given token amount
     * @param tokenAmount Amount of tokens to sell
     * @return ETH amount to receive
     */
    function getEthAmount(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Token amount must be > 0");
        uint256 price = getCurrentPrice();
        return (tokenAmount * price) / PRECISION;
    }

    /**
     * @notice Buy tokens with ETH
     */
    function buyTokens() external payable nonReentrant {
        require(msg.value > 0, "Must send ETH");

        uint256 tokenAmount = getTokenAmount(msg.value);
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");

        totalTokensSold += tokenAmount;
        totalEthRaised += msg.value;

        token.safeTransfer(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    /**
     * @notice Sell tokens for ETH
     * @param tokenAmount Amount of tokens to sell
     */
    function sellTokens(uint256 tokenAmount) external nonReentrant {
        require(tokenAmount > 0, "Token amount must be > 0");

        uint256 ethAmount = getEthAmount(tokenAmount);
        require(address(this).balance >= ethAmount, "Insufficient ETH in contract");

        totalTokensSold -= tokenAmount;
        totalEthRaised -= ethAmount;

        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        
        (bool success,) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        emit TokensSold(msg.sender, tokenAmount, ethAmount);
    }

    /**
     * @notice Update bonding curve parameters
     * @param _initialPrice New initial price
     * @param _slope New slope
     */
    function updatePriceParams(
        uint256 _initialPrice,
        uint256 _slope
    ) external onlyOwner {
        require(_initialPrice > 0, "Initial price must be > 0");
        require(_slope > 0, "Slope must be > 0");

        initialPrice = _initialPrice;
        slope = _slope;

        emit PriceParamsUpdated(_initialPrice, _slope);
    }

    /**
     * @notice Withdraw tokens from contract
     * @param amount Amount of tokens to withdraw
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Withdraw ETH from contract
     * @param amount Amount of ETH to withdraw
     */
    function withdrawEth(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    receive() external payable {}
}
