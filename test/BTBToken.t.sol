// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBYield} from "../src/BTBYield.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BTBYieldTest is Test {
    BTBYield public token;
    address public admin;
    address public user;
    uint256 public userPrivateKey;

    function setUp() public {
        admin = address(1);
        userPrivateKey = 0x1234; // Test private key
        user = vm.addr(userPrivateKey);
        
        vm.startPrank(admin);
        token = new BTBYield(admin);
        vm.stopPrank();
    }

    function test_InitialSetup() public {
        assertEq(token.name(), "BTB Yield");
        assertEq(token.symbol(), "BTBY");
        assertEq(token.decimals(), 18);
        assertEq(token.balanceOf(admin), 1000000000 * 10 ** 18);
    }
    
    function test_Transfer() public {
        uint256 transferAmount = 1000 * 10 ** 18;
        
        vm.startPrank(admin);
        token.transfer(user, transferAmount);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user), transferAmount);
        assertEq(token.balanceOf(admin), 1000000000 * 10 ** 18 - transferAmount);
    }
    
    function test_Permit() public {
        uint256 transferAmount = 1000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 days;
        
        // Transfer tokens to user first
        vm.startPrank(admin);
        token.transfer(user, transferAmount);
        vm.stopPrank();
        
        // Generate permit signature
        bytes32 permitHash = _getPermitDigest(
            address(token),
            user,
            address(this),
            transferAmount,
            0, // nonce
            deadline
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);
        
        // Use permit
        token.permit(user, address(this), transferAmount, deadline, v, r, s);
        
        // Check allowance was set
        assertEq(token.allowance(user, address(this)), transferAmount);
        
        // Use the allowance
        token.transferFrom(user, address(this), transferAmount);
        
        // Check balances
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(this)), transferAmount);
    }
    
    function _getPermitDigest(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        bytes32 domainSeparator = _getDomainSeparator(token);
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        
        bytes32 structHash = keccak256(
            abi.encode(
                permitTypehash,
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        
        return ECDSA.toTypedDataHash(domainSeparator, structHash);
    }
    
    function _getDomainSeparator(address tokenAddress) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("BTB Yield")),
                keccak256(bytes("1")),
                block.chainid,
                tokenAddress
            )
        );
    }
}
