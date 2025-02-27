// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1FeesTest is BTBExchangeV1Test {
    
    function test_InitialFeeValues() public {
        assertEq(exchange.buyFee(), 30);
        assertEq(exchange.sellFee(), 30);
        assertEq(exchange.adminFee(), 10);
        assertEq(exchange.getTotalFee(), 40); // buyFee + adminFee
        assertEq(exchange.getSellTotalFee(), 40); // sellFee + adminFee
    }
    
    function test_UpdateFees() public {
        vm.startPrank(owner);
        
        // Update fees
        uint256 newBuyFee = 50;
        uint256 newSellFee = 40;
        uint256 newAdminFee = 20;
        
        // Expect event
        vm.expectEmit(false, false, false, true);
        emit BTBExchangeV1.FeesUpdated(newBuyFee, newSellFee, newAdminFee);
        
        exchange.updateFees(newBuyFee, newSellFee, newAdminFee);
        
        // Verify new fee values
        assertEq(exchange.buyFee(), newBuyFee);
        assertEq(exchange.sellFee(), newSellFee);
        assertEq(exchange.adminFee(), newAdminFee);
        assertEq(exchange.getTotalFee(), newBuyFee + newAdminFee);
        assertEq(exchange.getSellTotalFee(), newSellFee + newAdminFee);
        
        vm.stopPrank();
    }
    
    function testFail_UpdateFeesExceedingPrecision() public {
        vm.startPrank(owner);
        
        // Try to set fees exceeding FEE_PRECISION
        uint256 invalidFee = FEE_PRECISION + 1;
        exchange.updateFees(invalidFee, 30, 10);
        
        vm.stopPrank();
    }
    
    function testFail_UpdateFeesFromNonOwner() public {
        vm.startPrank(user1);
        
        // Try to update fees as non-owner
        exchange.updateFees(50, 40, 20);
        
        vm.stopPrank();
    }
    
    function test_QuoteTokensForUsdc() public {
        // Test quoting tokens for a USDC amount
        uint256 usdcAmount = 1000e6; // 1000 USDC
        
        (
            uint256 tokenAmount,
            uint256 adminFeeAmount,
            uint256 platformFeeAmount,
            uint256 totalFeeAmount
        ) = exchange.quoteTokensForUsdc(usdcAmount);
        
        // Calculate expected values
        uint256 expectedAdminFee = (usdcAmount * exchange.adminFee()) / FEE_PRECISION;
        uint256 expectedPlatformFee = (usdcAmount * exchange.buyFee()) / FEE_PRECISION;
        uint256 expectedTotalFee = expectedAdminFee + expectedPlatformFee;
        uint256 usdcAfterFee = usdcAmount - expectedTotalFee;
        uint256 expectedTokenAmount = (usdcAfterFee * TOKEN_PRECISION) / exchange.getCurrentPrice();
        
        // Verify results
        assertEq(adminFeeAmount, expectedAdminFee);
        assertEq(platformFeeAmount, expectedPlatformFee);
        assertEq(totalFeeAmount, expectedTotalFee);
        assertEq(tokenAmount, expectedTokenAmount);
    }
    
    function test_QuoteTokensForZeroUsdc() public {
        // Test quoting tokens for zero USDC
        uint256 usdcAmount = 0;
        
        (
            uint256 tokenAmount,
            uint256 adminFeeAmount,
            uint256 platformFeeAmount,
            uint256 totalFeeAmount
        ) = exchange.quoteTokensForUsdc(usdcAmount);
        
        // All values should be zero
        assertEq(tokenAmount, 0);
        assertEq(adminFeeAmount, 0);
        assertEq(platformFeeAmount, 0);
        assertEq(totalFeeAmount, 0);
    }
    
    function test_QuoteUsdcForTokens() public {
        // Test quoting USDC for a token amount
        uint256 tokenAmount = 100e18; // 100 tokens
        
        (
            uint256 usdcAfterFee,
            uint256 adminFeeAmount,
            uint256 platformFeeAmount,
            uint256 totalFeeAmount
        ) = exchange.quoteUsdcForTokens(tokenAmount);
        
        // Calculate expected values
        uint256 price = exchange.getCurrentPrice();
        uint256 usdcAmount = (tokenAmount * price) / TOKEN_PRECISION;
        uint256 expectedPlatformFee = (usdcAmount * exchange.sellFee()) / FEE_PRECISION;
        uint256 expectedAdminFee = (usdcAmount * exchange.adminFee()) / FEE_PRECISION;
        uint256 expectedTotalFee = expectedPlatformFee + expectedAdminFee;
        uint256 expectedUsdcAfterFee = usdcAmount - expectedTotalFee;
        
        // Verify results
        assertEq(adminFeeAmount, expectedAdminFee);
        assertEq(platformFeeAmount, expectedPlatformFee);
        assertEq(totalFeeAmount, expectedTotalFee);
        assertEq(usdcAfterFee, expectedUsdcAfterFee);
    }
    
    function test_QuoteUsdcForZeroTokens() public {
        // Test quoting USDC for zero tokens
        uint256 tokenAmount = 0;
        
        (
            uint256 usdcAfterFee,
            uint256 adminFeeAmount,
            uint256 platformFeeAmount,
            uint256 totalFeeAmount
        ) = exchange.quoteUsdcForTokens(tokenAmount);
        
        // All values should be zero
        assertEq(usdcAfterFee, 0);
        assertEq(adminFeeAmount, 0);
        assertEq(platformFeeAmount, 0);
        assertEq(totalFeeAmount, 0);
    }
    
    function test_FeeCalculationsWithExtremeValues() public {
        // Test fee calculations with very large values
        uint256 largeUsdcAmount = 1_000_000e6; // 1 million USDC
        
        (
            uint256 tokenAmount,
            uint256 adminFeeAmount,
            uint256 platformFeeAmount,
            uint256 totalFeeAmount
        ) = exchange.quoteTokensForUsdc(largeUsdcAmount);
        
        // Verify fee calculations with large values
        uint256 expectedAdminFee = (largeUsdcAmount * exchange.adminFee()) / FEE_PRECISION;
        uint256 expectedPlatformFee = (largeUsdcAmount * exchange.buyFee()) / FEE_PRECISION;
        uint256 expectedTotalFee = expectedAdminFee + expectedPlatformFee;
        
        assertEq(adminFeeAmount, expectedAdminFee);
        assertEq(platformFeeAmount, expectedPlatformFee);
        assertEq(totalFeeAmount, expectedTotalFee);
        
        // Test with large token amount
        uint256 largeTokenAmount = 1_000_000e18; // 1 million tokens
        
        (
            uint256 usdcAfterFee,
            uint256 adminFeeAmount2,
            uint256 platformFeeAmount2,
            uint256 totalFeeAmount2
        ) = exchange.quoteUsdcForTokens(largeTokenAmount);
        
        // Verify calculations are correct and don't overflow
        assertTrue(usdcAfterFee > 0);
        assertTrue(adminFeeAmount2 > 0);
        assertTrue(platformFeeAmount2 > 0);
        assertTrue(totalFeeAmount2 > 0);
    }
}
