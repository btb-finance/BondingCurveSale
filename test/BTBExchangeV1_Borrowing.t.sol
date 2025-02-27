// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1BorrowingTest is BTBExchangeV1Test {
    
    function test_BorrowUsdc() public {
        vm.startPrank(owner);
        
        // Record balances before
        uint256 ownerUsdcBefore = usdcToken.balanceOf(owner);
        uint256 exchangeUsdcBefore = usdcToken.balanceOf(address(exchange));
        
        // Borrow USDC
        uint256 borrowAmount = 10_000e6;
        
        // Expect event
        vm.expectEmit(false, false, false, true);
        emit BTBExchangeV1.UsdcBorrowed(borrowAmount, borrowAmount);
        
        // Execute borrow
        exchange.borrowUsdc(borrowAmount);
        
        // Record balances after
        uint256 ownerUsdcAfter = usdcToken.balanceOf(owner);
        uint256 exchangeUsdcAfter = usdcToken.balanceOf(address(exchange));
        
        // Verify balances
        assertEq(ownerUsdcAfter - ownerUsdcBefore, borrowAmount);
        assertEq(exchangeUsdcBefore - exchangeUsdcAfter, borrowAmount);
        
        // Verify borrowed amount is tracked
        assertEq(exchange.usdcBorrowed(), borrowAmount);
        
        vm.stopPrank();
    }
    
    function testFail_BorrowZeroAmount() public {
        vm.startPrank(owner);
        
        // Try to borrow zero amount
        exchange.borrowUsdc(0);
        
        vm.stopPrank();
    }
    
    function testFail_BorrowMoreThanAvailable() public {
        vm.startPrank(owner);
        
        // Try to borrow more than available
        uint256 availableBalance = usdcToken.balanceOf(address(exchange));
        exchange.borrowUsdc(availableBalance + 1);
        
        vm.stopPrank();
    }
    
    function testFail_BorrowFromNonOwner() public {
        vm.startPrank(user1);
        
        // Try to borrow as non-owner
        exchange.borrowUsdc(1000e6);
        
        vm.stopPrank();
    }
    
    function test_RepayUsdc() public {
        // First borrow some USDC
        vm.startPrank(owner);
        uint256 borrowAmount = 10_000e6;
        exchange.borrowUsdc(borrowAmount);
        vm.stopPrank();
        
        // Approve USDC for repayment
        vm.startPrank(owner);
        usdcToken.approve(address(exchange), borrowAmount);
        
        // Record balances before
        uint256 ownerUsdcBefore = usdcToken.balanceOf(owner);
        uint256 exchangeUsdcBefore = usdcToken.balanceOf(address(exchange));
        
        // Repay USDC
        uint256 repayAmount = 5_000e6;
        
        // Expect event
        vm.expectEmit(false, false, false, true);
        emit BTBExchangeV1.UsdcRepaid(repayAmount, borrowAmount - repayAmount);
        
        // Execute repay
        exchange.repayUsdc(repayAmount);
        
        // Record balances after
        uint256 ownerUsdcAfter = usdcToken.balanceOf(owner);
        uint256 exchangeUsdcAfter = usdcToken.balanceOf(address(exchange));
        
        // Verify balances
        assertEq(ownerUsdcBefore - ownerUsdcAfter, repayAmount);
        assertEq(exchangeUsdcAfter - exchangeUsdcBefore, repayAmount);
        
        // Verify borrowed amount is updated
        assertEq(exchange.usdcBorrowed(), borrowAmount - repayAmount);
        
        vm.stopPrank();
    }
    
    function testFail_RepayZeroAmount() public {
        // First borrow some USDC
        vm.startPrank(owner);
        exchange.borrowUsdc(10_000e6);
        
        // Try to repay zero amount
        exchange.repayUsdc(0);
        
        vm.stopPrank();
    }
    
    function testFail_RepayMoreThanBorrowed() public {
        // First borrow some USDC
        vm.startPrank(owner);
        uint256 borrowAmount = 10_000e6;
        exchange.borrowUsdc(borrowAmount);
        usdcToken.approve(address(exchange), borrowAmount * 2);
        
        // Try to repay more than borrowed
        exchange.repayUsdc(borrowAmount + 1);
        
        vm.stopPrank();
    }
    
    function test_BorrowingImpactOnPrice() public {
        // Setup initial state with some circulation
        vm.startPrank(owner);
        btbToken.transfer(user1, 100_000e18);
        
        // Record initial price
        uint256 initialPrice = exchange.getCurrentPrice();
        
        // Borrow USDC
        uint256 borrowAmount = 50_000e6; // 50% of initial USDC
        exchange.borrowUsdc(borrowAmount);
        
        // Price should remain the same since borrowed USDC is included in calculation
        uint256 priceAfterBorrow = exchange.getCurrentPrice();
        assertEq(priceAfterBorrow, initialPrice);
        
        // Verify effective USDC balance includes borrowed amount
        assertEq(exchange.getEffectiveUsdcBalance(), usdcToken.balanceOf(address(exchange)) + borrowAmount);
        
        vm.stopPrank();
    }
    
    function test_PriceAfterRepayment() public {
        // Setup initial state with some circulation
        vm.startPrank(owner);
        btbToken.transfer(user1, 100_000e18);
        
        // Borrow USDC
        uint256 borrowAmount = 50_000e6;
        exchange.borrowUsdc(borrowAmount);
        
        // Record price after borrowing
        uint256 priceAfterBorrow = exchange.getCurrentPrice();
        
        // Approve and repay USDC
        usdcToken.approve(address(exchange), borrowAmount);
        exchange.repayUsdc(borrowAmount);
        
        // Price should remain the same after repayment
        uint256 priceAfterRepay = exchange.getCurrentPrice();
        assertEq(priceAfterRepay, priceAfterBorrow);
        
        // Verify borrowed amount is zero
        assertEq(exchange.usdcBorrowed(), 0);
        
        // Verify effective USDC balance equals actual balance
        assertEq(exchange.getEffectiveUsdcBalance(), exchange.getActualUsdcBalance());
        
        vm.stopPrank();
    }
    
    function test_MultipleBorrowsAndRepays() public {
        vm.startPrank(owner);
        
        // Multiple borrows
        exchange.borrowUsdc(10_000e6);
        assertEq(exchange.usdcBorrowed(), 10_000e6);
        
        exchange.borrowUsdc(20_000e6);
        assertEq(exchange.usdcBorrowed(), 30_000e6);
        
        // Approve for repayment
        usdcToken.approve(address(exchange), 30_000e6);
        
        // Multiple repays
        exchange.repayUsdc(5_000e6);
        assertEq(exchange.usdcBorrowed(), 25_000e6);
        
        exchange.repayUsdc(25_000e6);
        assertEq(exchange.usdcBorrowed(), 0);
        
        vm.stopPrank();
    }
}
