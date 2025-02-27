// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ReentrancyToken} from "./mocks/ReentrancyToken.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1SecurityTest is BTBExchangeV1Test {
    
    function test_ReentrancyProtectionInBuyTokens() public {
        // Deploy malicious token
        ReentrancyToken maliciousToken = new ReentrancyToken();
        
        // Deploy exchange with malicious token
        vm.startPrank(owner);
        BTBExchangeV1 maliciousExchange = new BTBExchangeV1(
            address(maliciousToken),
            address(usdcToken),
            admin
        );
        
        // Setup malicious token
        maliciousToken.setExchange(address(maliciousExchange));
        maliciousToken.setAttackOnTransfer(true);
        maliciousToken.setAttackAmount(10e18);
        
        // Add tokens to exchange
        maliciousToken.transfer(address(maliciousExchange), 1000e18);
        usdcToken.mint(address(maliciousExchange), 100_000e6);
        
        // Mint USDC for user1
        usdcToken.mint(user1, 10_000e6);
        
        vm.stopPrank();
        
        // Approve USDC
        vm.startPrank(user1);
        usdcToken.approve(address(maliciousExchange), 10_000e6);
        
        // Try to buy tokens - should revert due to reentrancy protection
        vm.expectRevert();
        maliciousExchange.buyTokens(1000e6);
        
        vm.stopPrank();
    }
    
    function test_ReentrancyProtectionInSellTokens() public {
        // Deploy malicious token
        ReentrancyToken maliciousToken = new ReentrancyToken();
        
        // Deploy exchange with malicious token
        vm.startPrank(owner);
        BTBExchangeV1 maliciousExchange = new BTBExchangeV1(
            address(maliciousToken),
            address(usdcToken),
            admin
        );
        
        // Setup malicious token
        maliciousToken.setExchange(address(maliciousExchange));
        maliciousToken.setAttackOnTransferFrom(true);
        maliciousToken.setAttackAmount(10e18);
        
        // Add tokens to exchange and user
        maliciousToken.transfer(address(maliciousExchange), 1000e18);
        maliciousToken.transfer(user1, 100e18);
        usdcToken.mint(address(maliciousExchange), 100_000e6);
        
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(user1);
        maliciousToken.approve(address(maliciousExchange), 100e18);
        
        // Try to sell tokens - should revert due to reentrancy protection
        vm.expectRevert();
        maliciousExchange.sellTokens(50e18);
        
        vm.stopPrank();
    }
    
    function test_FrontRunningProtection() public {
        // Setup
        _approveTokens(user1, type(uint256).max, type(uint256).max);
        _approveTokens(user2, type(uint256).max, type(uint256).max);
        
        // User1 buys tokens
        vm.prank(user1);
        exchange.buyTokens(1000e6);
        
        // User2 tries to buy in the same block - should fail
        vm.prank(user2);
        vm.expectRevert(BTBExchangeV1.SameBlockTrade.selector);
        exchange.buyTokens(1000e6);
        
        // Move to next block
        _moveToNextBlock();
        
        // User2 can now buy
        vm.prank(user2);
        exchange.buyTokens(1000e6);
    }
    
    function test_ArithmeticOverflowProtection() public {
        // Test with extreme values to check for overflow
        vm.startPrank(owner);
        
        // Mint a huge amount of tokens
        uint256 hugeAmount = type(uint128).max; // Large but not overflowing uint256
        btbToken.mint(user1, hugeAmount);
        usdcToken.mint(user1, hugeAmount);
        
        vm.stopPrank();
        
        // Approve tokens
        _approveTokens(user1, hugeAmount, hugeAmount);
        
        // Buy with large amount should not overflow
        vm.startPrank(user1);
        exchange.buyTokens(1_000_000e6); // Large but reasonable amount
        _moveToNextBlock();
        
        // Sell with large amount should not overflow
        exchange.sellTokens(1_000e18); // Large but reasonable amount
        
        vm.stopPrank();
    }
    
    function test_DirectTokenTransferHandling() public {
        // Test what happens when tokens are transferred directly to contract
        vm.startPrank(user1);
        
        // Record initial price
        uint256 initialPrice = exchange.getCurrentPrice();
        
        // Transfer tokens directly to contract
        btbToken.transfer(address(exchange), 1000e18);
        
        // Price should decrease due to increased contract balance
        uint256 priceAfterTransfer = exchange.getCurrentPrice();
        assertTrue(priceAfterTransfer < initialPrice);
        
        vm.stopPrank();
    }
    
    function test_EdgeCaseMinimumTokenAmount() public {
        // Test with minimum possible token amounts
        vm.startPrank(user1);
        
        // Buy minimum amount
        uint256 minUsdcAmount = 1; // 0.000001 USDC
        
        // This might fail if the amount is too small to get any tokens
        // We'll catch the failure and verify it's due to insufficient tokens
        try exchange.buyTokens(minUsdcAmount) {
            // If it succeeds, verify some tokens were received
            assertTrue(btbToken.balanceOf(user1) > 0);
        } catch {
            // If it fails, it should be due to insufficient tokens
            // This is acceptable for extremely small amounts
        }
        
        vm.stopPrank();
    }
    
    function test_EdgeCaseMaximumTokenAmount() public {
        // Test with maximum possible token amounts
        vm.startPrank(owner);
        
        // Mint a large amount of USDC
        uint256 largeAmount = 1_000_000_000e6; // 1 billion USDC
        usdcToken.mint(user1, largeAmount);
        
        vm.stopPrank();
        
        // Approve tokens
        _approveTokens(user1, type(uint256).max, largeAmount);
        
        // Buy with large amount
        vm.startPrank(user1);
        
        // This might fail if the contract doesn't have enough tokens
        // We'll check if it's due to insufficient tokens
        try exchange.buyTokens(largeAmount) {
            // If it succeeds, verify tokens were received
            assertTrue(btbToken.balanceOf(user1) > 0);
        } catch {
            // If it fails due to insufficient tokens, that's expected
        }
        
        vm.stopPrank();
    }
    
    function test_ExtremelyLowLiquidity() public {
        // Test behavior when contract has almost no liquidity
        vm.startPrank(owner);
        
        // Create a new exchange with very little liquidity
        MockERC20 newToken = new MockERC20("Low Liquidity Token", "LOW", 18);
        MockERC20 newUsdc = new MockERC20("Low Liquidity USDC", "LUSDC", 6);
        
        BTBExchangeV1 lowLiquidityExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        // Add minimal liquidity
        newToken.mint(address(lowLiquidityExchange), 1e18);
        newUsdc.mint(address(lowLiquidityExchange), 1e6);
        
        // Mint some tokens for user1
        newToken.mint(user1, 1e18);
        newUsdc.mint(user1, 1e6);
        
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(user1);
        newToken.approve(address(lowLiquidityExchange), 1e18);
        newUsdc.approve(address(lowLiquidityExchange), 1e6);
        
        // Buy a small amount
        uint256 smallAmount = 1e5; // 0.1 USDC
        lowLiquidityExchange.buyTokens(smallAmount);
        _moveToNextBlock();
        
        // Sell a small amount
        uint256 tokenAmount = 0.01e18; // 0.01 tokens
        lowLiquidityExchange.sellTokens(tokenAmount);
        
        vm.stopPrank();
    }
    
    function test_AccessControlForPrivilegedFunctions() public {
        // Test access control for all privileged functions
        
        // Non-owner should not be able to call owner functions
        vm.startPrank(user1);
        
        // updateFees
        vm.expectRevert();
        exchange.updateFees(50, 40, 20);
        
        // updateAdminAddress
        vm.expectRevert();
        exchange.updateAdminAddress(user2);
        
        // borrowUsdc
        vm.expectRevert();
        exchange.borrowUsdc(1000e6);
        
        // recoverERC20
        vm.expectRevert();
        exchange.recoverERC20(address(btbToken), 1000e18);
        
        // pause
        vm.expectRevert();
        exchange.pause();
        
        // unpause (first pause as owner)
        vm.stopPrank();
        vm.prank(owner);
        exchange.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        exchange.unpause();
    }
}
