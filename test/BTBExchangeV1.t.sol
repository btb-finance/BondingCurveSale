// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract BTBExchangeV1Test is Test {
    BTBExchangeV1 public exchange;
    MockERC20 public btbToken;
    MockERC20 public usdcToken;
    
    address public admin;
    address public owner;
    address public user1;
    address public user2;
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18; // 1 million tokens
    uint256 public constant INITIAL_USDC = 100_000e6;      // 100,000 USDC
    uint256 public constant USER_INITIAL_TOKENS = 100_000e18; // 100,000 tokens
    uint256 public constant USER_INITIAL_USDC = 100_000e6;    // 100,000 USDC
    
    // Constants from the contract - must match the actual contract values
    uint256 public constant PRECISION = 1e6;
    uint256 public constant TOKEN_PRECISION = 1e18;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant MIN_PRICE = 10000;
    uint256 public constant MIN_EFFECTIVE_CIRCULATION = 1e16;
    uint256 public constant MAX_INITIAL_PRICE = 100000;
    
    function setUp() public virtual {
        // Setup accounts
        admin = makeAddr("admin");
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy mock tokens
        vm.startPrank(owner);
        btbToken = new MockERC20("BTB Yield", "BTBY", 18);
        usdcToken = new MockERC20("USD Coin", "USDC", 6);
        
        // Deploy exchange contract
        exchange = new BTBExchangeV1(
            address(btbToken),
            address(usdcToken),
            admin
        );
        vm.stopPrank();
        
        // Setup initial balances for exchange
        vm.startPrank(owner);
        btbToken.mint(address(exchange), INITIAL_SUPPLY);
        usdcToken.mint(address(exchange), INITIAL_USDC);
        
        // Create some circulation to avoid MIN_EFFECTIVE_CIRCULATION issues
        btbToken.mint(address(0x1), 1e17); // 0.1 tokens for circulation
        
        // Mint tokens for users
        btbToken.mint(user1, USER_INITIAL_TOKENS);
        usdcToken.mint(user1, USER_INITIAL_USDC);
        btbToken.mint(user2, USER_INITIAL_TOKENS);
        usdcToken.mint(user2, USER_INITIAL_USDC);
        vm.stopPrank();
    }
    
    // Helper function to move to next block
    function _moveToNextBlock() internal {
        vm.roll(block.number + 1);
    }
    
    // Helper function to approve tokens for exchange
    function _approveTokens(address user, uint256 tokenAmount, uint256 usdcAmount) internal {
        vm.startPrank(user);
        btbToken.approve(address(exchange), tokenAmount);
        usdcToken.approve(address(exchange), usdcAmount);
        vm.stopPrank();
    }
    
    // Helper function to get token circulation
    function _getTokenCirculation() internal view returns (uint256) {
        return btbToken.totalSupply() - btbToken.balanceOf(address(exchange));
    }
    
    // Helper function to buy tokens
    function _buyTokens(address user, uint256 usdcAmount) internal returns (uint256 tokensBought) {
        uint256 tokenBalanceBefore = btbToken.balanceOf(user);
        
        vm.startPrank(user);
        exchange.buyTokens(usdcAmount);
        vm.stopPrank();
        
        uint256 tokenBalanceAfter = btbToken.balanceOf(user);
        tokensBought = tokenBalanceAfter - tokenBalanceBefore;
        
        return tokensBought;
    }
    
    // Helper function to sell tokens
    function _sellTokens(address user, uint256 tokenAmount) internal returns (uint256 usdcReceived) {
        uint256 usdcBalanceBefore = usdcToken.balanceOf(user);
        
        vm.startPrank(user);
        exchange.sellTokens(tokenAmount);
        vm.stopPrank();
        
        uint256 usdcBalanceAfter = usdcToken.balanceOf(user);
        usdcReceived = usdcBalanceAfter - usdcBalanceBefore;
        
        return usdcReceived;
    }
    
    // Helper function to check if a transaction reverts with a specific message
    function _expectRevertWithMessage(bytes memory encodedFunction, string memory expectedMessage) internal {
        (bool success, bytes memory returnData) = address(exchange).call(encodedFunction);
        assertFalse(success);
        assertEq(
            _getRevertMsg(returnData),
            expectedMessage
        );
    }
    
    // Helper function to extract revert message
    function _getRevertMsg(bytes memory returnData) internal pure returns (string memory) {
        // If the returnData length is less than 68, then the transaction reverted silently (without a reason string)
        if (returnData.length < 68) return "Transaction reverted silently";
        
        // Slice the sighash (4 bytes) and offset (32 bytes)
        bytes memory revertData = slice(returnData, 4, returnData.length - 4);
        
        // Extract the length of the revert string
        uint256 offset;
        assembly {
            offset := mload(add(revertData, 32))
        }
        
        // Extract the revert string
        bytes memory stringBytes = slice(revertData, 32 + offset, 32);
        uint256 length;
        assembly {
            length := mload(add(stringBytes, 32))
        }
        
        // Extract the actual string
        return string(slice(revertData, 64 + offset, length));
    }
    
    // Helper function to slice a bytes array
    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }
    
    // Helper function to get the current price
    function _getCurrentPrice() internal view returns (uint256) {
        return exchange.getCurrentPrice();
    }
    
    // Helper function to simulate a direct token transfer to the contract
    function _transferTokensDirectly(address from, uint256 amount) internal {
        vm.startPrank(from);
        btbToken.transfer(address(exchange), amount);
        vm.stopPrank();
    }
    
    // Helper function to simulate a direct USDC transfer to the contract
    function _transferUsdcDirectly(address from, uint256 amount) internal {
        vm.startPrank(from);
        usdcToken.transfer(address(exchange), amount);
        vm.stopPrank();
    }
    
    // Helper function to get token balance
    function _getTokenBalance(address account) internal view returns (uint256) {
        return btbToken.balanceOf(account);
    }
    
    // Helper function to get USDC balance
    function _getUsdcBalance(address account) internal view returns (uint256) {
        return usdcToken.balanceOf(account);
    }
    
    // Helper function to compare values with a percentage tolerance
    function _assertApproxEqRel(uint256 a, uint256 b, uint256 maxPercentDelta) internal {
        uint256 delta = a > b ? a - b : b - a;
        uint256 maxDelta = (b * maxPercentDelta) / 1e18;
        
        if (delta > maxDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("  Expected", b);
            emit log_named_uint("    Actual", a);
            emit log_named_uint("Max % Delta", maxPercentDelta / 1e16);
            emit log_named_uint("    % Delta", (delta * 1e18) / b / 1e16);
            fail();
        }
    }
}
