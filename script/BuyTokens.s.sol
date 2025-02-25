// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";

contract BuyTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchangeAddress = 0x1cEE9Bd2bdCD04e3880a51210AC78F5D70DD1B9B;
        address usdcAddress = 0xE5c212De64a5481E719d7c6ee8d00F2Cb9a20864;
        
        // Get contract instances
        BTBExchangeV1 exchange = BTBExchangeV1(exchangeAddress);
        MockUSDC usdc = MockUSDC(usdcAddress);
        
        // Get current price
        uint256 currentPrice = exchange.getCurrentPrice();
        console.log("Current price (in USDC with 6 decimals):", currentPrice);
        
        // We want to buy 1000 tokens
        // Plus fee
        uint256 usdcAmount = 10_000 * 10**6; // 10,000 USDC
        
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
