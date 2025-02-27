// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1PriceCalculationTest is BTBExchangeV1Test {
    
    function test_PriceCalculationWithNoCirculation() public {
        // Setup a scenario with no circulating tokens (all in contract)
        vm.startPrank(owner);
        MockERC20 newToken = new MockERC20("New Token", "NEW", 18);
        MockERC20 newUsdc = new MockERC20("New USDC", "NUSDC", 6);
        
        BTBExchangeV1 newExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        uint256 totalSupply = 1_000_000e18;
        newToken.mint(address(newExchange), totalSupply);
        newUsdc.mint(address(newExchange), 100_000e6);
        
        // All tokens are in the contract, so circulation is 0
        assertEq(newToken.balanceOf(address(newExchange)), totalSupply);
        assertEq(newToken.totalSupply(), totalSupply);
        
        // Price should be MIN_PRICE
        assertEq(newExchange.getCurrentPrice(), MIN_PRICE);
        vm.stopPrank();
    }
    
    function test_PriceCalculationWithCirculation() public {
        // Setup a scenario with some circulating tokens
        vm.startPrank(owner);
        btbToken.transfer(user1, 100_000e18); // Transfer from contract to user
        
        // Calculate expected price
        uint256 circulatingSupply = 100_000e18;
        uint256 usdcBalance = 100_000e6;
        uint256 expectedPrice = (usdcBalance * TOKEN_PRECISION) / circulatingSupply;
        
        // Verify price
        assertEq(exchange.getCurrentPrice(), expectedPrice);
        vm.stopPrank();
    }
    
    function test_PriceCalculationBelowMinPrice() public {
        // Setup a scenario where calculated price would be below MIN_PRICE
        vm.startPrank(owner);
        
        // Transfer most tokens out of contract to create high circulation
        uint256 transferAmount = 999_990e18;
        btbToken.transfer(user1, transferAmount);
        
        // Remove most USDC to make price low
        usdcToken.transfer(user1, 99_900e6);
        
        // With high circulation and low USDC, price would be below MIN_PRICE
        uint256 circulatingSupply = transferAmount;
        uint256 usdcBalance = 100e6;
        uint256 calculatedPrice = (usdcBalance * TOKEN_PRECISION) / circulatingSupply;
        
        // Verify calculated price is below MIN_PRICE
        assertTrue(calculatedPrice < MIN_PRICE);
        
        // Verify actual price is capped at MIN_PRICE
        assertEq(exchange.getCurrentPrice(), MIN_PRICE);
        vm.stopPrank();
    }
    
    function test_PriceCapWithLowCirculation() public {
        // Setup a scenario where price would exceed MAX_INITIAL_PRICE with low circulation
        vm.startPrank(owner);
        
        // Create a very small circulation
        uint256 circulationAmount = MIN_EFFECTIVE_CIRCULATION / 2; // Below minimum effective circulation
        btbToken.transfer(user1, circulationAmount);
        
        // Add a lot of USDC to make price high
        usdcToken.mint(address(exchange), 1_000_000e6);
        
        // Verify circulation is below MIN_EFFECTIVE_CIRCULATION
        uint256 totalSupply = btbToken.totalSupply();
        uint256 contractBalance = btbToken.balanceOf(address(exchange));
        uint256 circulatingSupply = totalSupply - contractBalance;
        assertTrue(circulatingSupply < MIN_EFFECTIVE_CIRCULATION);
        
        // Verify price is capped at MAX_INITIAL_PRICE
        assertEq(exchange.getCurrentPrice(), MAX_INITIAL_PRICE);
        vm.stopPrank();
    }
    
    function test_MinimumEffectiveCirculation() public {
        // Test that circulation below MIN_EFFECTIVE_CIRCULATION uses the minimum
        vm.startPrank(owner);
        
        // Create a circulation just below minimum
        uint256 circulationAmount = MIN_EFFECTIVE_CIRCULATION - 1e15;
        btbToken.transfer(user1, circulationAmount);
        
        // Calculate price using MIN_EFFECTIVE_CIRCULATION
        uint256 usdcBalance = usdcToken.balanceOf(address(exchange));
        uint256 expectedPrice = (usdcBalance * TOKEN_PRECISION) / MIN_EFFECTIVE_CIRCULATION;
        
        // Verify price calculation uses minimum effective circulation
        assertEq(exchange.getCurrentPrice(), expectedPrice);
        vm.stopPrank();
    }
    
    function test_BorrowedUsdcImpactOnPrice() public {
        // Test that borrowed USDC is included in price calculation
        vm.startPrank(owner);
        
        // Setup initial state
        uint256 circulationAmount = 100_000e18;
        btbToken.transfer(user1, circulationAmount);
        uint256 initialPrice = exchange.getCurrentPrice();
        
        // Borrow some USDC
        uint256 borrowAmount = 10_000e6;
        exchange.borrowUsdc(borrowAmount);
        
        // Price should remain the same since borrowed USDC is included in calculation
        assertEq(exchange.getCurrentPrice(), initialPrice);
        
        // Verify borrowed amount is tracked correctly
        assertEq(exchange.usdcBorrowed(), borrowAmount);
        assertEq(exchange.getEffectiveUsdcBalance(), usdcToken.balanceOf(address(exchange)) + borrowAmount);
        vm.stopPrank();
    }
    
    function test_PriceCalculationWithExtremeValues() public {
        // Test price calculation with very large values
        vm.startPrank(owner);
        
        // Create a large circulation
        uint256 largeCirculation = 900_000e18;
        btbToken.transfer(user1, largeCirculation);
        
        // Add a lot of USDC
        uint256 largeUsdcAmount = 10_000_000e6;
        usdcToken.mint(address(exchange), largeUsdcAmount);
        
        // Calculate expected price
        uint256 totalUsdcBalance = usdcToken.balanceOf(address(exchange));
        uint256 circulatingSupply = btbToken.totalSupply() - btbToken.balanceOf(address(exchange));
        uint256 expectedPrice = (totalUsdcBalance * TOKEN_PRECISION) / circulatingSupply;
        
        // Verify price
        assertEq(exchange.getCurrentPrice(), expectedPrice);
        vm.stopPrank();
    }
}
