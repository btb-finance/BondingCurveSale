// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/BTBYield.sol";

contract SellBTBYScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address btbYield = 0xCeC34c32EBb2eF111077b61D2C7913095bC26cd9;
        address exchange = 0x12452904BE81b20eF06EE39fA2c7c49E27456EDf;
        
        // Get contract instances
        BTBYield token = BTBYield(btbYield);
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);
        
        // Amount to sell: 1,000,000 BTBY tokens (with 18 decimals)
        uint256 sellAmount = 1_000_000 * 10**18;
        
        // First approve BTBY tokens for exchange
        token.approve(exchange, sellAmount);
        console.log("Approved BTBY tokens for selling. Amount:", sellAmount);
        
        // Sell BTBY tokens
        btbExchange.sellTokens(sellAmount);
        console.log("Sold BTBY tokens. Amount:", sellAmount);

        vm.stopBroadcast();
    }
}
