// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1TradingTest is BTBExchangeV1Test {
    
    function setUp() public override {
        super.setUp();
        
        // Approve tokens for trading
        _approveTokens(user1, type(uint256).max, type(uint256).max);
        _approveTokens(user2, type(uint256).max, type(uint256).max);
    }
    
    function test_BuyTokens() public {
        vm.startPrank(user1);
        
        // Record balances before
        uint256 userUsdcBefore = usdcToken.balanceOf(user1);
        uint256 userTokenBefore = btbToken.balanceOf(user1);
        uint256 exchangeUsdcBefore = usdcToken.balanceOf(address(exchange));
        uint256 exchangeTokenBefore = btbToken.balanceOf(address(exchange));
        uint256 adminUsdcBefore = usdcToken.balanceOf(admin);
        
        // Buy tokens
        uint256 usdcAmount = 1000e6; // 1000 USDC
        
        // Get quote to compare with actual results
        (
            uint256 expectedTokenAmount,
            uint256 expectedAdminFee,
            uint256 expectedPlatformFee,
            uint256 expectedTotalFee
        ) = exchange.quoteTokensForUsdc(usdcAmount);
        
        // Expect event
        vm.expectEmit(true, false, false, true);
        emit BTBExchangeV1.TokensBought(user1, usdcAmount, expectedTokenAmount, exchange.getTotalFee());
        
        // Execute buy
        exchange.buyTokens(usdcAmount);
        
        // Record balances after
        uint256 userUsdcAfter = usdcToken.balanceOf(user1);
        uint256 userTokenAfter = btbToken.balanceOf(user1);
        uint256 exchangeUsdcAfter = usdcToken.balanceOf(address(exchange));
        uint256 exchangeTokenAfter = btbToken.balanceOf(address(exchange));
        uint256 adminUsdcAfter = usdcToken.balanceOf(admin);
        
        // Verify balances
        assertEq(userUsdcBefore - userUsdcAfter, usdcAmount);
        assertEq(userTokenAfter - userTokenBefore, expectedTokenAmount);
        assertEq(exchangeUsdcAfter - exchangeUsdcBefore, usdcAmount - expectedAdminFee);
        assertEq(exchangeTokenBefore - exchangeTokenAfter, expectedTokenAmount);
        assertEq(adminUsdcAfter - adminUsdcBefore, expectedAdminFee);
        
        // Verify lastTradeBlock was updated
        assertEq(exchange.lastTradeBlock(), block.number);
        
        vm.stopPrank();
    }
    
    function testFail_BuyTokensWithZeroAmount() public {
        vm.startPrank(user1);
        
        // Try to buy with zero USDC
        exchange.buyTokens(0);
        
        vm.stopPrank();
    }
    
    function testFail_BuyTokensInSameBlock() public {
        vm.startPrank(user1);
        
        // Buy tokens first time
        exchange.buyTokens(1000e6);
        
        // Try to buy again in the same block
        exchange.buyTokens(1000e6);
        
        vm.stopPrank();
    }
    
    function test_BuyTokensInDifferentBlocks() public {
        vm.startPrank(user1);
        
        // Buy tokens first time
        exchange.buyTokens(1000e6);
        
        // Move to next block
        _moveToNextBlock();
        
        // Buy again in a different block - should succeed
        exchange.buyTokens(1000e6);
        
        vm.stopPrank();
    }
    
    function testFail_BuyTokensWhenPaused() public {
        // Pause the contract
        vm.prank(owner);
        exchange.pause();
        
        vm.startPrank(user1);
        
        // Try to buy when paused
        exchange.buyTokens(1000e6);
        
        vm.stopPrank();
    }
    
    function testFail_BuyTokensInsufficientBalance() public {
        // Setup a scenario where contract has insufficient tokens
        vm.startPrank(owner);
        
        // Create a new exchange with very few tokens
        MockERC20 newToken = new MockERC20("New Token", "NEW", 18);
        MockERC20 newUsdc = new MockERC20("New USDC", "NUSDC", 6);
        
        BTBExchangeV1 newExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        // Add only a small amount of tokens to the exchange
        newToken.mint(address(newExchange), 1e18);
        newUsdc.mint(address(newExchange), 100_000e6);
        
        // Mint tokens for user1
        newUsdc.mint(user1, 10_000e6);
        
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(user1);
        newUsdc.approve(address(newExchange), type(uint256).max);
        
        // Try to buy more tokens than available
        newExchange.buyTokens(10_000e6);
        
        vm.stopPrank();
    }
    
    function test_SellTokens() public {
        // First buy some tokens to sell
        vm.startPrank(user1);
        exchange.buyTokens(1000e6);
        _moveToNextBlock();
        
        // Record balances before selling
        uint256 userUsdcBefore = usdcToken.balanceOf(user1);
        uint256 userTokenBefore = btbToken.balanceOf(user1);
        uint256 exchangeUsdcBefore = usdcToken.balanceOf(address(exchange));
        uint256 exchangeTokenBefore = btbToken.balanceOf(address(exchange));
        uint256 adminUsdcBefore = usdcToken.balanceOf(admin);
        
        // Sell tokens
        uint256 tokenAmount = 10e18; // 10 tokens
        
        // Get quote to compare with actual results
        (
            uint256 expectedUsdcAmount,
            uint256 expectedAdminFee,
            uint256 expectedPlatformFee,
            uint256 expectedTotalFee
        ) = exchange.quoteUsdcForTokens(tokenAmount);
        
        // Expect event
        vm.expectEmit(true, false, false, true);
        emit BTBExchangeV1.TokensSold(user1, tokenAmount, expectedUsdcAmount, exchange.getSellTotalFee());
        
        // Execute sell
        exchange.sellTokens(tokenAmount);
        
        // Record balances after
        uint256 userUsdcAfter = usdcToken.balanceOf(user1);
        uint256 userTokenAfter = btbToken.balanceOf(user1);
        uint256 exchangeUsdcAfter = usdcToken.balanceOf(address(exchange));
        uint256 exchangeTokenAfter = btbToken.balanceOf(address(exchange));
        uint256 adminUsdcAfter = usdcToken.balanceOf(admin);
        
        // Verify balances
        assertEq(userUsdcAfter - userUsdcBefore, expectedUsdcAmount);
        assertEq(userTokenBefore - userTokenAfter, tokenAmount);
        assertEq(exchangeUsdcBefore - exchangeUsdcAfter, expectedUsdcAmount + expectedAdminFee);
        assertEq(exchangeTokenAfter - exchangeTokenBefore, tokenAmount);
        assertEq(adminUsdcAfter - adminUsdcBefore, expectedAdminFee);
        
        // Verify lastTradeBlock was updated
        assertEq(exchange.lastTradeBlock(), block.number);
        
        vm.stopPrank();
    }
    
    function testFail_SellTokensWithZeroAmount() public {
        vm.startPrank(user1);
        
        // Try to sell zero tokens
        exchange.sellTokens(0);
        
        vm.stopPrank();
    }
    
    function testFail_SellTokensInSameBlock() public {
        vm.startPrank(user1);
        
        // Buy some tokens first
        exchange.buyTokens(1000e6);
        _moveToNextBlock();
        
        // Sell tokens first time
        exchange.sellTokens(10e18);
        
        // Try to sell again in the same block
        exchange.sellTokens(10e18);
        
        vm.stopPrank();
    }
    
    function test_SellTokensInDifferentBlocks() public {
        vm.startPrank(user1);
        
        // Buy some tokens first
        exchange.buyTokens(1000e6);
        _moveToNextBlock();
        
        // Sell tokens first time
        exchange.sellTokens(10e18);
        
        // Move to next block
        _moveToNextBlock();
        
        // Sell again in a different block - should succeed
        exchange.sellTokens(10e18);
        
        vm.stopPrank();
    }
    
    function testFail_SellTokensWhenPaused() public {
        // Buy some tokens first
        vm.startPrank(user1);
        exchange.buyTokens(1000e6);
        vm.stopPrank();
        
        // Pause the contract
        vm.prank(owner);
        exchange.pause();
        
        vm.startPrank(user1);
        
        // Try to sell when paused
        exchange.sellTokens(10e18);
        
        vm.stopPrank();
    }
    
    function testFail_SellTokensInsufficientUsdcBalance() public {
        // Setup a scenario where contract has insufficient USDC
        vm.startPrank(owner);
        
        // Create a new exchange with very little USDC
        MockERC20 newToken = new MockERC20("New Token", "NEW", 18);
        MockERC20 newUsdc = new MockERC20("New USDC", "NUSDC", 6);
        
        BTBExchangeV1 newExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        // Add tokens to the exchange but very little USDC
        newToken.mint(address(newExchange), 1000e18);
        newUsdc.mint(address(newExchange), 1e6); // Only 1 USDC
        
        // Mint tokens for user1
        newToken.mint(user1, 100e18);
        
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(user1);
        newToken.approve(address(newExchange), type(uint256).max);
        
        // Try to sell tokens for more USDC than available
        newExchange.sellTokens(100e18);
        
        vm.stopPrank();
    }
    
    function test_BuyAndSellImpactOnPrice() public {
        vm.startPrank(user1);
        
        // Record initial price
        uint256 initialPrice = exchange.getCurrentPrice();
        
        // Buy a significant amount of tokens
        uint256 buyAmount = 10_000e6; // 10,000 USDC
        exchange.buyTokens(buyAmount);
        _moveToNextBlock();
        
        // Price should increase after buying
        uint256 priceAfterBuy = exchange.getCurrentPrice();
        assertTrue(priceAfterBuy > initialPrice);
        
        // Sell some tokens
        (uint256 tokenAmount,,, ) = exchange.quoteTokensForUsdc(buyAmount);
        exchange.sellTokens(tokenAmount);
        _moveToNextBlock();
        
        // Price should return close to initial price
        uint256 priceAfterSell = exchange.getCurrentPrice();
        assertApproxEqRel(priceAfterSell, initialPrice, 0.01e18); // Within 1%
        
        vm.stopPrank();
    }
}
