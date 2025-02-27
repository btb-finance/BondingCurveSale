// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract TestPriceAfterTransferScript is Script {
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

        // Get current price
        uint256 price = btbExchange.getCurrentPrice();
        console.log("\nCurrent price:", price / 1e6, "USDC per BTBY");
        
        // Get exchange balance
        uint256 exchangeBalance = btbToken.balanceOf(exchange);
        console.log("Exchange BTBY balance:", exchangeBalance / 1e18, "BTBY");
        
        // Test quote for 1000 USDC
        uint256 usdcAmount = 1000 * 10**6;
        (uint256 quotedTokens, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteTokensForUsdc(usdcAmount);
            
        console.log("\nQuote for", usdcAmount / 1e6, "USDC:");
        console.log("Expected BTBY tokens:", quotedTokens / 1e18, "BTBY");
        console.log("Total fees:", totalFee / 1e6, "USDC");
        
        // Test quote for selling 100 BTBY
        uint256 sellAmount = 100 * 10**18;
        (uint256 usdcReturn, uint256 sellAdminFee, uint256 sellPlatformFee, uint256 sellTotalFee) = 
            btbExchange.quoteUsdcForTokens(sellAmount);
            
        console.log("\nQuote for selling", sellAmount / 1e18, "BTBY:");
        console.log("Expected USDC return:", usdcReturn / 1e6, "USDC");
        console.log("Total fees:", sellTotalFee / 1e6, "USDC");

        vm.stopBroadcast();
    }
}
