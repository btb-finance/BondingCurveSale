// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";
import "../src/BTBExchangeV1.sol";

contract TransferAllBTBYScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address btbYield = 0x47170eA51BF13019d7e1Eb666a0D2e19767d2397;
        address exchange = 0xa1bA1F0210319dd7e8abd51229012B692420a346;
        
        // Get contract instances
        BTBYield token = BTBYield(btbYield);
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);
        
        // Get current price before transfer
        uint256 priceBefore = btbExchange.getCurrentPrice();
        console.log("\nPrice before transfer:", priceBefore / 1e6, "USDC per BTBY");
        
        // Get wallet balance
        address wallet = vm.addr(deployerPrivateKey);
        uint256 balance = token.balanceOf(wallet);
        console.log("\nWallet BTBY balance:", balance / 1e18, "BTBY");
        
        // Transfer all tokens to exchange
        token.transfer(exchange, balance);
        console.log("Transferred all BTBY tokens to exchange");
        
        // Get new price after transfer
        uint256 priceAfter = btbExchange.getCurrentPrice();
        console.log("\nPrice after transfer:", priceAfter / 1e6, "USDC per BTBY");
        
        // Show exchange balance
        uint256 exchangeBalance = token.balanceOf(exchange);
        console.log("Exchange BTBY balance:", exchangeBalance / 1e18, "BTBY");

        vm.stopBroadcast();
    }
}
