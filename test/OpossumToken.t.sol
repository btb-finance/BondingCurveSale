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
        
        vm.prank(minter);
        token.burn(user, 500e18);
        
        assertEq(token.balanceOf(user), 500e18);
    }

    function testFail_UnauthorizedMint() public {
        vm.prank(user);
        token.mint(user, 1000e18);
    }

    function testFail_UnauthorizedBurn() public {
        // First mint some tokens
        vm.prank(minter);
        token.mint(user, 1000e18);
        
        vm.prank(user);
        token.burn(user, 500e18);
    }

    function test_RoleManagement() public {
        address newMinter = makeAddr("newMinter");
        token.grantMinterRole(newMinter);
        assertTrue(token.hasRole(token.MINTER_ROLE(), newMinter));
        
        token.revokeMinterRole(newMinter);
        assertFalse(token.hasRole(token.MINTER_ROLE(), newMinter));
    }

    function test_Permit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        address spender = address(0xCAFE);
        uint256 value = 1e18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // Get the current nonce
        uint256 nonce = token.nonces(owner);
        
        // Get domain separator
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        
        // Get permit typehash
        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        
        // Create permit
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // Execute permit
        token.permit(owner, spender, value, deadline, v, r, s);
        
        // Verify allowance
        assertEq(token.allowance(owner, spender), value);
    }
}
