// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBYield} from "../src/BTBYield.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BTBYieldTest is Test {
    BTBYield public token;
    address public admin;
    address public minter;
    address public user;
    uint256 public userPrivateKey;

    function setUp() public {
        admin = address(1);
        minter = address(2);
        userPrivateKey = 0x1234; // Test private key
        user = vm.addr(userPrivateKey);
        
        vm.startPrank(admin);
        token = new BTBYield(admin, minter);
        vm.stopPrank();
    }

    function test_InitialSetup() public {
        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(token.hasRole(token.MINTER_ROLE(), minter), true);
        assertEq(token.name(), "BTB Yield");
        assertEq(token.symbol(), "BTBY");
        assertEq(token.decimals(), 18);
    }

    function test_Minting() public {
        vm.startPrank(minter);
        token.mint(user, 100e18);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 100e18);
        assertEq(token.totalSupply(), 100e18);
    }

    function test_OnlyMinterCanMint() public {
        vm.startPrank(user);
        vm.expectRevert();
        token.mint(user, 100e18);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_Transfer() public {
        vm.startPrank(minter);
        token.mint(user, 100e18);
        vm.stopPrank();

        vm.startPrank(user);
        token.transfer(address(4), 50e18);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 50e18);
        assertEq(token.balanceOf(address(4)), 50e18);
    }

    function test_AdminCanGrantMinterRole() public {
        address newMinter = address(5);
        
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), newMinter);
        vm.stopPrank();

        vm.startPrank(newMinter);
        token.mint(user, 100e18);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 100e18);
    }

    function test_Permit() public {
        address spender = address(4);
        uint256 value = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);
        
        // Generate permit signature
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                user,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);

        // Execute permit
        token.permit(user, spender, value, deadline, v, r, s);

        // Verify allowance
        assertEq(token.allowance(user, spender), value);
        assertEq(token.nonces(user), 1);
    }
}
