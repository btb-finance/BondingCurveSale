// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract TransferBTBScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address btbYield = 0xCeC34c32EBb2eF111077b61D2C7913095bC26cd9;
        address exchange = 0x12452904BE81b20eF06EE39fA2c7c49E27456EDf;
        
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
