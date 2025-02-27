// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1AdminTest is BTBExchangeV1Test {
    
    function test_UpdateAdminAddress() public {
        vm.startPrank(owner);
        
        address newAdmin = makeAddr("newAdmin");
        
        // Expect event
        vm.expectEmit(true, false, false, false);
        emit BTBExchangeV1.AdminAddressUpdated(newAdmin);
        
        // Update admin address
        exchange.updateAdminAddress(newAdmin);
        
        // Verify admin was updated
        assertEq(exchange.adminAddress(), newAdmin);
        
        vm.stopPrank();
    }
    
    function testFail_UpdateAdminAddressToZero() public {
        vm.startPrank(owner);
        
        // Try to update admin to zero address
        exchange.updateAdminAddress(address(0));
        
        vm.stopPrank();
    }
    
    function testFail_UpdateAdminAddressFromNonOwner() public {
        vm.startPrank(user1);
        
        // Try to update admin as non-owner
        exchange.updateAdminAddress(user2);
        
        vm.stopPrank();
    }
    
    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        
        // Verify initial state is not paused
        assertTrue(!exchange.paused());
        
        // Pause the contract
        exchange.pause();
        
        // Verify contract is paused
        assertTrue(exchange.paused());
        
        // Unpause the contract
        exchange.unpause();
        
        // Verify contract is not paused
        assertTrue(!exchange.paused());
        
        vm.stopPrank();
    }
    
    function testFail_PauseFromNonOwner() public {
        vm.startPrank(user1);
        
        // Try to pause as non-owner
        exchange.pause();
        
        vm.stopPrank();
    }
    
    function testFail_UnpauseFromNonOwner() public {
        // Pause the contract
        vm.prank(owner);
        exchange.pause();
        
        vm.startPrank(user1);
        
        // Try to unpause as non-owner
        exchange.unpause();
        
        vm.stopPrank();
    }
    
    function test_FeeDistributionAfterAdminChange() public {
        // Setup
        _approveTokens(user1, type(uint256).max, type(uint256).max);
        
        // Change admin address
        address newAdmin = makeAddr("newAdmin");
        vm.prank(owner);
        exchange.updateAdminAddress(newAdmin);
        
        // Buy tokens
        vm.startPrank(user1);
        uint256 usdcAmount = 1000e6;
        
        // Get expected admin fee
        (, uint256 expectedAdminFee,,) = exchange.quoteTokensForUsdc(usdcAmount);
        
        // Record admin balance before
        uint256 newAdminUsdcBefore = usdcToken.balanceOf(newAdmin);
        
        // Buy tokens
        exchange.buyTokens(usdcAmount);
        
        // Verify fee went to new admin
        uint256 newAdminUsdcAfter = usdcToken.balanceOf(newAdmin);
        assertEq(newAdminUsdcAfter - newAdminUsdcBefore, expectedAdminFee);
        
        vm.stopPrank();
    }
    
    function test_RecoverERC20() public {
        vm.startPrank(owner);
        
        // Create a test token
        MockERC20 testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(exchange), 1000e18);
        
        // Verify initial balance
        assertEq(testToken.balanceOf(address(exchange)), 1000e18);
        assertEq(testToken.balanceOf(owner), 0);
        
        // Expect event
        vm.expectEmit(true, false, false, true);
        emit BTBExchangeV1.TokensWithdrawn(address(testToken), 1000e18);
        
        // Recover tokens
        exchange.recoverERC20(address(testToken), 1000e18);
        
        // Verify balances after recovery
        assertEq(testToken.balanceOf(address(exchange)), 0);
        assertEq(testToken.balanceOf(owner), 1000e18);
        
        vm.stopPrank();
    }
    
    function testFail_RecoverERC20FromNonOwner() public {
        vm.startPrank(user1);
        
        // Try to recover tokens as non-owner
        exchange.recoverERC20(address(btbToken), 1000e18);
        
        vm.stopPrank();
    }
}
