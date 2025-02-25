// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/BTBYield.sol";

contract SellTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchangeAddress = 0x1cEE9Bd2bdCD04e3880a51210AC78F5D70DD1B9B;
        address btbAddress = 0xAF36A1B261e42946F47B6eEd24db5478E9b46F16;
        
        // Get contract instances
        BTBExchangeV1 exchange = BTBExchangeV1(exchangeAddress);
        BTBYield btb = BTBYield(btbAddress);
        
        // Get current price
        uint256 currentPrice = exchange.getCurrentPrice();
        console.log("Current price (in USDC with 6 decimals):", currentPrice);
        
        // We want to sell 0.5 token (with 18 decimals)
        uint256 tokenAmount = 5 * 10**17; // 0.5 BTB token
        
        // Get balance before sale
        address deployer = vm.addr(deployerPrivateKey);
        uint256 usdcBefore = exchange.usdc().balanceOf(deployer);
        uint256 btbBefore = btb.balanceOf(deployer);
        console.log("BTB balance before:", btbBefore / 10**18);
        console.log("USDC balance before:", usdcBefore / 10**6);
        
        // Sell tokens
        exchange.sellTokens(tokenAmount);
        console.log("Sold BTB amount:", tokenAmount / 10**18);
        
        // Get balance after sale
        uint256 usdcAfter = exchange.usdc().balanceOf(deployer);
        uint256 btbAfter = btb.balanceOf(deployer);
        console.log("BTB balance after:", btbAfter / 10**18);
        console.log("USDC balance after:", usdcAfter / 10**6);
        console.log("USDC received:", (usdcAfter - usdcBefore) / 10**6);

        // Get new price after sale
        uint256 newPrice = exchange.getCurrentPrice();
        console.log("New price (in USDC):", newPrice / 10**6);

        vm.stopBroadcast();
    }
}
