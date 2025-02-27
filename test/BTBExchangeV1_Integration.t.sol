// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1IntegrationTest is BTBExchangeV1Test {
    
    function setUp() public override {
        super.setUp();
        
        // Approve tokens for all tests
        _approveTokens(user1, type(uint256).max, type(uint256).max);
        _approveTokens(user2, type(uint256).max, type(uint256).max);
    }
    
    function test_SequentialTrades() public {
        // Record initial price
        uint256 initialPrice = _getCurrentPrice();
        
        // User1 buys tokens
        uint256 usdcAmount1 = 5000e6;
        uint256 tokensBought1 = _buyTokens(user1, usdcAmount1);
        _moveToNextBlock();
        
        // Price should increase
        uint256 priceAfterBuy1 = _getCurrentPrice();
        assertTrue(priceAfterBuy1 > initialPrice);
        console2.log("Initial price: %s", initialPrice);
        console2.log("Price after buy 1: %s", priceAfterBuy1);
        
        // User2 buys tokens
        uint256 usdcAmount2 = 10000e6;
        uint256 tokensBought2 = _buyTokens(user2, usdcAmount2);
        _moveToNextBlock();
        
        // Price should increase further
        uint256 priceAfterBuy2 = _getCurrentPrice();
        assertTrue(priceAfterBuy2 > priceAfterBuy1);
        console2.log("Price after buy 2: %s", priceAfterBuy2);
        
        // User1 sells tokens
        uint256 usdcReceived1 = _sellTokens(user1, tokensBought1 / 2);
        _moveToNextBlock();
        
        // Price should decrease
        uint256 priceAfterSell1 = _getCurrentPrice();
        assertTrue(priceAfterSell1 < priceAfterBuy2);
        console2.log("Price after sell 1: %s", priceAfterSell1);
        
        // User2 sells tokens
        uint256 usdcReceived2 = _sellTokens(user2, tokensBought2 / 2);
        _moveToNextBlock();
        
        // Price should decrease further
        uint256 priceAfterSell2 = _getCurrentPrice();
        assertTrue(priceAfterSell2 < priceAfterSell1);
        console2.log("Price after sell 2: %s", priceAfterSell2);
        
        // User1 buys more tokens
        _buyTokens(user1, usdcReceived1);
        _moveToNextBlock();
        
        // Price should increase again
        uint256 priceAfterBuy3 = _getCurrentPrice();
        assertTrue(priceAfterBuy3 > priceAfterSell2);
        console2.log("Price after buy 3: %s", priceAfterBuy3);
        
        // User2 buys more tokens
        _buyTokens(user2, usdcReceived2);
        _moveToNextBlock();
        
        // Price should increase further
        uint256 priceAfterBuy4 = _getCurrentPrice();
        assertTrue(priceAfterBuy4 > priceAfterBuy3);
        console2.log("Price after buy 4: %s", priceAfterBuy4);
    }
    
    function test_BorrowingAndTradingInteraction() public {
        // Record initial price
        uint256 initialPrice = _getCurrentPrice();
        
        // Owner borrows USDC
        vm.startPrank(owner);
        uint256 borrowAmount = 10000e6;
        exchange.borrowUsdc(borrowAmount);
        vm.stopPrank();
        
        // Price should increase due to reduced USDC in contract
        uint256 priceAfterBorrow = _getCurrentPrice();
        assertTrue(priceAfterBorrow > initialPrice);
        console2.log("Initial price: %s", initialPrice);
        console2.log("Price after borrow: %s", priceAfterBorrow);
        
        // User1 buys tokens
        uint256 usdcAmount = 5000e6;
        uint256 tokensBought = _buyTokens(user1, usdcAmount);
        _moveToNextBlock();
        
        // Price should increase further
        uint256 priceAfterBuy = _getCurrentPrice();
        assertTrue(priceAfterBuy > priceAfterBorrow);
        console2.log("Price after buy: %s", priceAfterBuy);
        
        // Owner repays USDC
        vm.startPrank(owner);
        usdcToken.mint(owner, borrowAmount);
        usdcToken.approve(address(exchange), borrowAmount);
        exchange.repayUsdc(borrowAmount);
        vm.stopPrank();
        
        // Price should decrease
        uint256 priceAfterRepay = _getCurrentPrice();
        assertTrue(priceAfterRepay < priceAfterBuy);
        console2.log("Price after repay: %s", priceAfterRepay);
        
        // User1 sells tokens
        _sellTokens(user1, tokensBought);
        _moveToNextBlock();
        
        // Price should decrease further
        uint256 priceAfterSell = _getCurrentPrice();
        assertTrue(priceAfterSell < priceAfterRepay);
        console2.log("Price after sell: %s", priceAfterSell);
    }
    
    function test_ContractWithImbalancedReserves() public {
        // Create a new exchange with imbalanced reserves
        vm.startPrank(owner);
        MockERC20 newToken = new MockERC20("Imbalanced Token", "IMBAL", 18);
        MockERC20 newUsdc = new MockERC20("Imbalanced USDC", "IUSDC", 6);
        
        BTBExchangeV1 imbalancedExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        // Add imbalanced tokens to exchange (much more tokens than USDC)
        newToken.mint(address(imbalancedExchange), 10_000_000e18); // 10 million tokens
        newUsdc.mint(address(imbalancedExchange), 10_000e6);       // Only 10,000 USDC
        
        // Create circulation
        newToken.mint(address(0x1), 1e17);
        
        // Mint tokens for user1
        newToken.mint(user1, 100_000e18);
        newUsdc.mint(user1, 100_000e6);
        
        // Approve tokens
        vm.stopPrank();
        
        vm.startPrank(user1);
        newToken.approve(address(imbalancedExchange), type(uint256).max);
        newUsdc.approve(address(imbalancedExchange), type(uint256).max);
        
        // Check initial price (should be low due to imbalance)
        uint256 initialPrice = imbalancedExchange.getCurrentPrice();
        console2.log("Initial price with imbalanced reserves: %s", initialPrice);
        
        // Buy tokens
        uint256 usdcAmount = 1000e6;
        imbalancedExchange.buyTokens(usdcAmount);
        
        // Check price after buy
        uint256 priceAfterBuy = imbalancedExchange.getCurrentPrice();
        console2.log("Price after buy with imbalanced reserves: %s", priceAfterBuy);
        assertTrue(priceAfterBuy > initialPrice);
        
        vm.stopPrank();
    }
    
    function test_LargeVsSmallTradeImpact() public {
        // Record initial price
        uint256 initialPrice = _getCurrentPrice();
        
        // User1 makes a large trade
        uint256 largeAmount = 50000e6; // 50,000 USDC
        uint256 tokensBoughtLarge = _buyTokens(user1, largeAmount);
        _moveToNextBlock();
        
        // Record price after large trade
        uint256 priceAfterLarge = _getCurrentPrice();
        uint256 priceDiffLarge = priceAfterLarge - initialPrice;
        
        // Reset the state
        vm.startPrank(user1);
        btbToken.approve(address(exchange), tokensBoughtLarge);
        exchange.sellTokens(tokensBoughtLarge);
        vm.stopPrank();
        _moveToNextBlock();
        
        // Verify price is back to initial
        uint256 priceAfterReset = _getCurrentPrice();
        _assertApproxEqRel(priceAfterReset, initialPrice, 0.01e18); // Within 1%
        
        // User2 makes multiple small trades totaling the same amount
        uint256 smallAmount = 5000e6; // 5,000 USDC
        uint256 numTrades = 10; // 10 trades of 5,000 USDC = 50,000 USDC total
        
        uint256 totalTokensBoughtSmall = 0;
        for (uint256 i = 0; i < numTrades; i++) {
            totalTokensBoughtSmall += _buyTokens(user2, smallAmount);
            _moveToNextBlock();
        }
        
        // Record price after small trades
        uint256 priceAfterSmall = _getCurrentPrice();
        uint256 priceDiffSmall = priceAfterSmall - priceAfterReset;
        
        // Compare price impact
        console2.log("Price impact of large trade: %s", priceDiffLarge);
        console2.log("Price impact of multiple small trades: %s", priceDiffSmall);
        
        // Due to the bonding curve, multiple small trades should have a different
        // price impact than a single large trade of the same total amount
        assertTrue(priceDiffLarge != priceDiffSmall);
    }
    
    function test_PriceImpactWithExtremeChanges() public {
        // Record initial price
        uint256 initialPrice = _getCurrentPrice();
        
        // User1 buys a very large amount of tokens, but not too large to cause failure
        uint256 largeAmount = 50000e6; // 50,000 USDC (half of the USDC in the contract)
        uint256 tokensBought = _buyTokens(user1, largeAmount);
        _moveToNextBlock();
        
        // Price should increase significantly
        uint256 priceAfterBuy = _getCurrentPrice();
        assertTrue(priceAfterBuy > initialPrice);
        console2.log("Initial price: %s", initialPrice);
        console2.log("Price after large buy: %s", priceAfterBuy);
        
        // User1 sells all tokens
        uint256 usdcReceived = _sellTokens(user1, tokensBought);
        _moveToNextBlock();
        
        // Price should decrease
        uint256 priceAfterSell = _getCurrentPrice();
        assertTrue(priceAfterSell < priceAfterBuy);
        console2.log("Price after large sell: %s", priceAfterSell);
        
        // Price should be close to initial price
        _assertApproxEqRel(priceAfterSell, initialPrice, 0.05e18); // Within 5%
    }
    
    function test_GasUsageUnderVariousConditions() public {
        // Measure gas for buying tokens under different conditions
        
        // 1. Normal buy
        uint256 gasBefore = gasleft();
        _buyTokens(user1, 1000e6);
        uint256 gasUsedNormalBuy = gasBefore - gasleft();
        _moveToNextBlock();
        
        // 2. Small buy
        gasBefore = gasleft();
        _buyTokens(user1, 10e6);
        uint256 gasUsedSmallBuy = gasBefore - gasleft();
        _moveToNextBlock();
        
        // 3. Large buy
        gasBefore = gasleft();
        _buyTokens(user1, 10000e6);
        uint256 gasUsedLargeBuy = gasBefore - gasleft();
        _moveToNextBlock();
        
        // Log gas usage
        console2.log("Gas used for normal buy (1,000 USDC): %s", gasUsedNormalBuy);
        console2.log("Gas used for small buy (10 USDC): %s", gasUsedSmallBuy);
        console2.log("Gas used for large buy (10,000 USDC): %s", gasUsedLargeBuy);
        
        // Measure gas for selling tokens under different conditions
        
        // 1. Normal sell
        gasBefore = gasleft();
        _sellTokens(user1, 100e18);
        uint256 gasUsedNormalSell = gasBefore - gasleft();
        _moveToNextBlock();
        
        // 2. Small sell
        gasBefore = gasleft();
        _sellTokens(user1, 1e18);
        uint256 gasUsedSmallSell = gasBefore - gasleft();
        _moveToNextBlock();
        
        // 3. Large sell
        gasBefore = gasleft();
        _sellTokens(user1, 1000e18);
        uint256 gasUsedLargeSell = gasBefore - gasleft();
        
        // Log gas usage
        console2.log("Gas used for normal sell (100 tokens): %s", gasUsedNormalSell);
        console2.log("Gas used for small sell (1 token): %s", gasUsedSmallSell);
        console2.log("Gas used for large sell (1,000 tokens): %s", gasUsedLargeSell);
    }
}
