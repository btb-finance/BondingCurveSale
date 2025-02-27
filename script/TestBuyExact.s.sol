// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract TestBuyExactScript is Script {
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

        // Amount to buy (1000 USDC)
        uint256 usdcAmount = 1000 * 10**6;
        
        // Get initial balances
        uint256 initialBTBY = btbToken.balanceOf(vm.addr(deployerPrivateKey));
        uint256 initialUSDC = usdcToken.balanceOf(vm.addr(deployerPrivateKey));
        
        console.log("\nInitial balances:");
        console.log("BTBY:", initialBTBY / 1e18, "BTBY");
        console.log("USDC:", initialUSDC / 1e6, "USDC");
        
        // Get quote first
        (uint256 quotedTokens, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteTokensForUsdc(usdcAmount);
            
        console.log("\nQuote for", usdcAmount / 1e6, "USDC:");
        console.log("Expected BTBY tokens:", quotedTokens / 1e18, "BTBY");
        console.log("Total fees:", totalFee / 1e6, "USDC");
        
        // Approve and buy tokens
        usdcToken.approve(exchange, usdcAmount);
        btbExchange.buyTokens(usdcAmount);
        
        // Get final balances
        uint256 finalBTBY = btbToken.balanceOf(vm.addr(deployerPrivateKey));
        uint256 finalUSDC = usdcToken.balanceOf(vm.addr(deployerPrivateKey));
        
        console.log("\nFinal balances:");
        console.log("BTBY:", finalBTBY / 1e18, "BTBY");
        console.log("USDC:", finalUSDC / 1e6, "USDC");
        
        console.log("\nActual changes:");
        console.log("BTBY received:", (finalBTBY - initialBTBY) / 1e18, "BTBY");
        console.log("USDC spent:", (initialUSDC - finalUSDC) / 1e6, "USDC");
        
        // Verify if quote matches actual
        bool quotedMatchesActual = (finalBTBY - initialBTBY) == quotedTokens;
        console.log("\nQuote matches actual received:", quotedMatchesActual ? "Yes" : "No");

        vm.stopBroadcast();
    }
}
