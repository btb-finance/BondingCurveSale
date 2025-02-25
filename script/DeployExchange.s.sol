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
        address btbYield = 0xAF36A1B261e42946F47B6eEd24db5478E9b46F16; // BTB token
        address usdc = 0xE5c212De64a5481E719d7c6ee8d00F2Cb9a20864;    // USDC token
        
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
