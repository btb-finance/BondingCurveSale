// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract SellTokensScript is Script {
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

        // Get initial state
        address wallet = vm.addr(deployerPrivateKey);
        uint256 initialPrice = btbExchange.getCurrentPrice();
        uint256 initialBTBY = btbToken.balanceOf(wallet);
        uint256 initialUSDC = usdcToken.balanceOf(wallet);
        uint256 initialExchangeBTBY = btbToken.balanceOf(exchange);
        
        console.log("\nInitial state:");
        console.log("Price:", initialPrice / 1e6, "USDC per BTBY");
        console.log("Your BTBY balance:", initialBTBY / 1e18, "BTBY");
        console.log("Your USDC balance:", initialUSDC / 1e6, "USDC");
        console.log("Exchange BTBY balance:", initialExchangeBTBY / 1e18, "BTBY");
        
        // Amount to sell (10,000 BTBY)
        uint256 sellAmount = 10000000000000000000000; // 10,000 BTBY with 18 decimals
        
        // Get quote first
        (uint256 usdcAfterFee, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteUsdcForTokens(sellAmount);
            
        console.log("\nSelling", sellAmount / 1e18, "BTBY:");
        console.log("Expected USDC return:", usdcAfterFee / 1e6, "USDC");
        console.log("Admin fee:", adminFee / 1e6, "USDC");
        console.log("Platform fee:", platformFee / 1e6, "USDC");
        console.log("Total fees:", totalFee / 1e6, "USDC");
        
        // Approve and sell tokens
        btbToken.approve(exchange, sellAmount);
        btbExchange.sellTokens(sellAmount);
        
        // Get final state
        uint256 finalPrice = btbExchange.getCurrentPrice();
        uint256 finalBTBY = btbToken.balanceOf(wallet);
        uint256 finalUSDC = usdcToken.balanceOf(wallet);
        uint256 finalExchangeBTBY = btbToken.balanceOf(exchange);
        
        console.log("\nFinal state:");
        console.log("New price:", finalPrice / 1e6, "USDC per BTBY");
        console.log("Your BTBY balance:", finalBTBY / 1e18, "BTBY");
        console.log("Your USDC balance:", finalUSDC / 1e6, "USDC");
        console.log("Exchange BTBY balance:", finalExchangeBTBY / 1e18, "BTBY");
        
        console.log("\nChanges:");
        console.log("Price change:", (finalPrice > initialPrice ? "+" : "-"), (finalPrice - initialPrice) / 1e6, "USDC");
        console.log("BTBY sold:", (initialBTBY - finalBTBY) / 1e18, "BTBY");
        console.log("USDC received:", (finalUSDC - initialUSDC) / 1e6, "USDC");

        vm.stopBroadcast();
    }
}
