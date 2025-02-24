// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";
import "../src/BTBExchangeV1.sol";

contract MigrateTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Contract addresses
        address oldExchangeAddress = 0xBb535A3dbeEa0e2eAce9dF4caFEA8A1a4d0D8Ff6;
        address newExchangeAddress = 0x36B8c4D45dF7E09325991b185262580bA34e1298;
        BTBYield token = BTBYield(0xf2DfA80e04287186D73431Af0Ab09321D8E97DbA);
        
        // Get token balance in old exchange
        uint256 balance = token.balanceOf(oldExchangeAddress);
        console.log("Old exchange token balance:", balance);

        // First transfer tokens to deployer
        BTBExchangeV1(oldExchangeAddress).withdrawUsdc(balance);
        console.log("Withdrawn tokens from old exchange");

        // Then transfer to new exchange
        token.transfer(newExchangeAddress, balance);
        console.log("Transferred tokens to new exchange:", balance);

        vm.stopBroadcast();
    }
}
