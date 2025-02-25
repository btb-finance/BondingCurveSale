// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/BTBYield.sol";

contract SellBTBYScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address btbYield = 0xA83Cb2f4fA7eD1d77E60EDcc4d0E99EfDA38A050;
        address exchange = 0x728EAE530d80E29a27074903775421A41eFd614A;
        
        // Get contract instances
        BTBYield token = BTBYield(btbYield);
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);
        
        // Amount to sell: 10,000 BTBY tokens (with 18 decimals)
        uint256 sellAmount = 10_000 * 10**18;
        
        // First approve BTBY tokens for exchange
        token.approve(exchange, sellAmount);
        console.log("Approved BTBY tokens for selling. Amount:", sellAmount);
        
        // Sell BTBY tokens
        btbExchange.sellTokens(sellAmount);
        console.log("Sold BTBY tokens. Amount:", sellAmount);

        vm.stopBroadcast();
    }
}
