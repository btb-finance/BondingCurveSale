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
        address btbYield = 0xCeC34c32EBb2eF111077b61D2C7913095bC26cd9; // BTB token
        address usdc = 0x741973E28394F26F75CB1A09303aab3c43180D31;    // USDC token
        
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
