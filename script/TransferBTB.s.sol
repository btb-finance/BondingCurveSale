// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract TransferBTBScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address btbYield = 0xA83Cb2f4fA7eD1d77E60EDcc4d0E99EfDA38A050;
        address exchange = 0x728EAE530d80E29a27074903775421A41eFd614A;
        
        // Get contract instance
        BTBYield token = BTBYield(btbYield);
        
        // Transfer all tokens to exchange
        address deployer = vm.addr(deployerPrivateKey);
        uint256 balance = token.balanceOf(deployer);
        token.transfer(exchange, balance);
        console.log("Transferred all BTB tokens to exchange. Amount:", balance);

        vm.stopBroadcast();
    }
}
