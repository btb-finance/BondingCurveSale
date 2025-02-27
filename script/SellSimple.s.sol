// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract SellSimpleScript is Script {
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

        // Amount to sell (10,000 BTBY)
        uint256 sellAmount = 10000000000000000000000; // 10,000 BTBY with 18 decimals
        
        // Get quote and verify it matches expected
        (uint256 usdcAfterFee, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteUsdcForTokens(sellAmount);
            
        // Verify the quote matches expected return
        require(usdcAfterFee == 500071680, "Quote does not match expected return");
        require(adminFee == 502080, "Admin fee does not match");
        require(platformFee == 1506240, "Platform fee does not match");
        require(totalFee == 2008320, "Total fee does not match");
        
        // Approve and sell tokens
        btbToken.approve(exchange, sellAmount);
        btbExchange.sellTokens(sellAmount);

        vm.stopBroadcast();
    }
}
