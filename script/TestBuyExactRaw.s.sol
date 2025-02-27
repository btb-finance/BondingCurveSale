// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract TestBuyExactRawScript is Script {
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

        // Amount to buy (1000 USDC = 1000000000 in USDC decimals)
        uint256 usdcAmount = 1000 * 10**6;
        
        // Get initial balances
        uint256 initialBTBY = btbToken.balanceOf(vm.addr(deployerPrivateKey));
        uint256 initialUSDC = usdcToken.balanceOf(vm.addr(deployerPrivateKey));
        
        console.log("\nRaw balances (with decimals):");
        console.log("Initial BTBY:", initialBTBY);
        console.log("Initial USDC:", initialUSDC);
        
        // Get quote first
        (uint256 quotedTokens, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteTokensForUsdc(usdcAmount);
            
        console.log("\nQuote (raw numbers):");
        console.log("USDC input:", usdcAmount);
        console.log("Expected BTBY:", quotedTokens);
        console.log("Admin fee:", adminFee);
        console.log("Platform fee:", platformFee);
        console.log("Total fee:", totalFee);
        
        // Approve and buy tokens
        usdcToken.approve(exchange, usdcAmount);
        btbExchange.buyTokens(usdcAmount);
        
        // Get final balances
        uint256 finalBTBY = btbToken.balanceOf(vm.addr(deployerPrivateKey));
        uint256 finalUSDC = usdcToken.balanceOf(vm.addr(deployerPrivateKey));
        
        console.log("\nFinal raw balances:");
        console.log("Final BTBY:", finalBTBY);
        console.log("Final USDC:", finalUSDC);
        
        console.log("\nActual changes (raw):");
        console.log("BTBY received:", finalBTBY - initialBTBY);
        console.log("USDC spent:", initialUSDC - finalUSDC);

        vm.stopBroadcast();
    }
}
