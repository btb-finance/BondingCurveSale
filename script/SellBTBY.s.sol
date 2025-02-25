// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/BTBYield.sol";

contract SellBTBYScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address btbYield = 0x656e098E175c614BF14e9cE5a17736E25322920B;
        address exchange = 0xEed45965dd5DD2Fed4EA614fFA29cFF6CE974914;
        
        // Get contract instances
        BTBYield token = BTBYield(btbYield);
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);
        
        // Amount to sell: 1000 BTBY tokens (with 18 decimals)
        uint256 sellAmount = 1000 * 10**18;
        
        // First approve BTBY tokens for exchange
        token.approve(exchange, sellAmount);
        console.log("Approved BTBY tokens for selling. Amount:", sellAmount);
        
        // Sell BTBY tokens
        btbExchange.sellTokens(sellAmount);
        console.log("Sold BTBY tokens. Amount:", sellAmount);

        vm.stopBroadcast();
    }
}
