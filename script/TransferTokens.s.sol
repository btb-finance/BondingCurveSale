// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract TransferTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchangeAddress = 0x36B8c4D45dF7E09325991b185262580bA34e1298;
        BTBYield token = BTBYield(0xf2DfA80e04287186D73431Af0Ab09321D8E97DbA);
        
        // Get deployer's balance
        address deployer = vm.addr(deployerPrivateKey);
        uint256 balance = token.balanceOf(deployer);
        
        // Transfer all tokens to exchange
        token.transfer(exchangeAddress, balance);
        console.log("Transferred tokens to exchange:", balance);

        vm.stopBroadcast();
    }
}
