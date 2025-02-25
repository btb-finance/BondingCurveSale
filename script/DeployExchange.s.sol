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
        address btbYield = 0x656e098E175c614BF14e9cE5a17736E25322920B; // BTB token
        address usdc = 0x452387742c56993A47F35425DdCbb05000681FC6;    // USDC token
        
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
