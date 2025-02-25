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
        address btbYield = 0xA83Cb2f4fA7eD1d77E60EDcc4d0E99EfDA38A050; // BTB token
        address usdc = 0x334f5A3ecC0c6dCea6d438a532B20dAe20806bC6;    // USDC token
        
        // Deploy BTBExchangeV1
        BTBExchangeV1 exchange = new BTBExchangeV1(
            btbYield,    // BTBYield token
            usdc,        // USDC token
            deployer     // Admin address
        );
        console.log("BTBExchangeV1 deployed at:", address(exchange));

        vm.stopBroadcast();
    }
}
