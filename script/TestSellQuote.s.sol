// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract TestSellQuoteScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchange = 0xa1bA1F0210319dd7e8abd51229012B692420a346;
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);

        // Test selling 100 BTBY tokens
        uint256 tokenAmount = 100 * 10**18; // 100 BTBY
        
        // Get sell quote
        (uint256 usdcAfterFee, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteUsdcForTokens(tokenAmount);
            
        console.log("\nQuote for selling", tokenAmount, "BTBY tokens:");
        console.log("Expected USDC after fees:", usdcAfterFee);
        console.log("Admin fee:", adminFee);
        console.log("Platform fee:", platformFee);
        console.log("Total fee:", totalFee);
        console.log("Total USDC (including fees):", usdcAfterFee + totalFee);

        vm.stopBroadcast();
    }
}
