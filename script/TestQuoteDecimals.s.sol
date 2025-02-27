// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract TestQuoteDecimalsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchange = 0xa1bA1F0210319dd7e8abd51229012B692420a346;
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);

        // Test with 1000 USDC (1000000000 in USDC decimals)
        uint256 usdcAmount = 1000 * 10**6; // 1000 USDC
        
        // Get quote
        (uint256 tokenAmount, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteTokensForUsdc(usdcAmount);
            
        console.log("\nInput:");
        console.log("USDC amount:", usdcAmount / 1e6, "USDC");
        
        console.log("\nFees:");
        console.log("Admin fee:", adminFee / 1e6, "USDC");
        console.log("Platform fee:", platformFee / 1e6, "USDC");
        console.log("Total fee:", totalFee / 1e6, "USDC");
        
        console.log("\nOutput:");
        console.log("BTBY tokens to receive:", tokenAmount / 1e18, "BTBY");
        console.log("USDC amount after fees:", (usdcAmount - totalFee) / 1e6, "USDC");

        // Get current price
        uint256 price = btbExchange.getCurrentPrice();
        console.log("\nCurrent price:", price / 1e6, "USDC per BTBY");

        vm.stopBroadcast();
    }
}
