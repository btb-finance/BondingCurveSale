// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";

contract DeployExchangeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        
        // Token addresses
        address btbYield = 0xf2DfA80e04287186D73431Af0Ab09321D8E97DbA; // New token address
        address usdc = 0x0EC98Aa4218e9dB07C8fF0D2ADe4b8e8e6DD2E5F;    // Existing USDC
        
        // Fee settings (in basis points)
        uint256 buyFee = 100;  // 1% buy fee
        uint256 sellFee = 100; // 1% sell fee
        
        // Deploy BTBExchangeV1
        BTBExchangeV1 exchange = new BTBExchangeV1(
            btbYield,    // BTBYield token
            usdc,        // USDC token
            buyFee,      // Buy fee (1%)
            sellFee      // Sell fee (1%)
        );
        console.log("BTBExchangeV1 deployed at:", address(exchange));

        vm.stopBroadcast();
    }
}
