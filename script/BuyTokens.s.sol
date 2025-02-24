// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";

contract BuyTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchangeAddress = 0xBb535A3dbeEa0e2eAce9dF4caFEA8A1a4d0D8Ff6;
        address usdcAddress = 0x0EC98Aa4218e9dB07C8fF0D2ADe4b8e8e6DD2E5F;
        
        // Get contract instances
        BTBExchangeV1 exchange = BTBExchangeV1(exchangeAddress);
        MockUSDC usdc = MockUSDC(usdcAddress);
        
        // Get current price
        uint256 currentPrice = exchange.getCurrentPrice();
        console.log("Current price (in USDC with 6 decimals):", currentPrice);
        
        // We want to buy 100 tokens
        // Each token costs 0.01 USDC (10000 with 6 decimals)
        // Total cost = 100 * 0.01 = 1 USDC
        // Plus 1% fee = 1.01 USDC
        uint256 usdcAmount = 1010000; // 1.01 USDC with 6 decimals
        
        // First approve USDC spending
        usdc.approve(exchangeAddress, usdcAmount);
        console.log("Approved USDC spending:", usdcAmount);
        
        // Get balance before purchase
        address deployer = vm.addr(deployerPrivateKey);
        uint256 balanceBefore = exchange.token().balanceOf(deployer);
        console.log("Token balance before (in wei):", balanceBefore);
        
        // Buy tokens
        exchange.buyTokens(usdcAmount);
        console.log("Bought tokens with", usdcAmount, "USDC");
        
        // Get balance after purchase
        uint256 balanceAfter = exchange.token().balanceOf(deployer);
        console.log("Token balance after (in wei):", balanceAfter);
        console.log("Tokens received (in wei):", balanceAfter - balanceBefore);
        console.log("Tokens received (in whole tokens):", (balanceAfter - balanceBefore) / 1e18);

        // Get new price after purchase
        uint256 newPrice = exchange.getCurrentPrice();
        console.log("New price (in USDC with 6 decimals):", newPrice);

        vm.stopBroadcast();
    }
}
