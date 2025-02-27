// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract TestQuoteScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address usdc = 0x966be3DF28040313a6eCC5c925f07b169b87cBB7;
        address btbYield = 0x47170eA51BF13019d7e1Eb666a0D2e19767d2397;
        address exchange = 0xa1bA1F0210319dd7e8abd51229012B692420a346;
        
        // Get contract instances
        MockUSDC usdcToken = MockUSDC(usdc);
        BTBYield btbToken = BTBYield(btbYield);
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);

        // Amount of USDC to test (1000 USDC)
        uint256 usdcAmount = 1000 * 10**6;
        
        // Get quote first
        (uint256 quotedTokens, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteTokensForUsdc(usdcAmount);
            
        console.log("Quote for", usdcAmount, "USDC:");
        console.log("Expected BTBY tokens:", quotedTokens);
        console.log("Admin fee:", adminFee);
        console.log("Platform fee:", platformFee);
        console.log("Total fee:", totalFee);
        
        // Get initial balances
        uint256 initialBTBY = btbToken.balanceOf(vm.addr(deployerPrivateKey));
        
        // Approve and buy tokens
        usdcToken.approve(exchange, usdcAmount);
        btbExchange.buyTokens(usdcAmount);
        
        // Get final balance
        uint256 finalBTBY = btbToken.balanceOf(vm.addr(deployerPrivateKey));
        uint256 actualTokensReceived = finalBTBY - initialBTBY;
        
        console.log("\nActual transaction results:");
        console.log("BTBY tokens received:", actualTokensReceived);
        
        // Compare results
        if (quotedTokens == actualTokensReceived) {
            console.log("\nSUCCESS: Quote matches actual tokens received!");
        } else {
            console.log("\nERROR: Quote does not match actual tokens received!");
            console.log("Difference:", 
                quotedTokens > actualTokensReceived ? 
                quotedTokens - actualTokensReceived : 
                actualTokensReceived - quotedTokens
            );
        }

        vm.stopBroadcast();
    }
}
