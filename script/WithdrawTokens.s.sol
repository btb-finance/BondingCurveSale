// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract WithdrawTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Old exchange address
        address oldExchangeAddress = 0xBb535A3dbeEa0e2eAce9dF4caFEA8A1a4d0D8Ff6;
        BTBYield token = BTBYield(0xf2DfA80e04287186D73431Af0Ab09321D8E97DbA);
        
        // Get token balance in old exchange
        uint256 balance = token.balanceOf(oldExchangeAddress);
        console.log("Old exchange token balance:", balance);
        
        // Get deployer address
        address deployer = vm.addr(deployerPrivateKey);

        // Call approve on behalf of the old exchange (since we're the owner)
        vm.prank(oldExchangeAddress);
        token.approve(deployer, balance);
        console.log("Approved token transfer");
        
        // Transfer tokens from old exchange to deployer
        token.transferFrom(oldExchangeAddress, deployer, balance);
        console.log("Withdrawn tokens from old exchange:", balance);

        vm.stopBroadcast();
    }
}
