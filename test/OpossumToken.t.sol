// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {OpossumToken} from "../src/OpossumToken.sol";

contract OpossumTokenTest is Test {
    OpossumToken public token;
    address public admin;
    address public minter;
    address public user;

    function setUp() public {
        admin = address(this);
        minter = makeAddr("minter");
        user = makeAddr("user");
        
        token = new OpossumToken(admin, minter);
    }

    function test_InitialState() public {
        assertEq(token.name(), "OPOSSUM");
        assertEq(token.symbol(), "OPOS");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.BURNER_ROLE(), minter));
    }

    function test_MintTokens() public {
        vm.prank(minter);
        token.mint(user, 1000e18);
        
        assertEq(token.balanceOf(user), 1000e18);
    }

    function test_BurnTokens() public {
        // First mint some tokens
        vm.prank(minter);
        token.mint(user, 1000e18);
        
        // Switch to user to burn their own tokens
        vm.prank(user);
        token.burn(500e18);
        
        assertEq(token.balanceOf(user), 500e18);
    }

    function testFail_UnauthorizedMint() public {
        vm.prank(user);
        token.mint(user, 1000e18);
    }

    function test_GrantRole() public {
        address newMinter = makeAddr("newMinter");
        
        vm.prank(admin);
        token.grantRole(token.MINTER_ROLE(), newMinter);
        
        assertTrue(token.hasRole(token.MINTER_ROLE(), newMinter));
    }
}
