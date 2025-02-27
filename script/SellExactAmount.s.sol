// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";
import "../src/BTBYield.sol";

contract SellExactAmountScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address wallet = vm.addr(deployerPrivateKey);
        
        // Token addresses
        address btbYield = 0x47170eA51BF13019d7e1Eb666a0D2e19767d2397; // BTB token
        address usdc = 0x966be3DF28040313a6eCC5c925f07b169b87cBB7;    // USDC token
        address exchange = 0x728EAE530d80E29a27074903775421A41eFd614A; // Exchange contract
        
        // Connect to existing contracts
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);
        IERC20 btbToken = IERC20(btbYield);
        IERC20 usdcToken = IERC20(usdc);
        
        // Get current price and balances
        uint256 initialPrice = btbExchange.getCurrentPrice();
        uint256 initialBTBY = btbToken.balanceOf(wallet);
        uint256 initialUSDC = usdcToken.balanceOf(wallet);
        uint256 initialExchangeBTBY = btbToken.balanceOf(exchange);
        
        // Amount to sell (10,000 BTBY)
        uint256 sellAmount = 10000000000000000000000; // 10,000 BTBY with 18 decimals
        
        (uint256 usdcAfterFee, uint256 adminFee, uint256 platformFee, uint256 totalFee) = 
            btbExchange.quoteUsdcForTokens(sellAmount);
            
        // Verify the quote matches expected return
        require(usdcAfterFee == 500071680, "Quote does not match expected return");
        
        // Approve tokens for exchange
        btbToken.approve(exchange, sellAmount);
        
        // Sell tokens
        btbExchange.sellTokens(sellAmount);
        
        // Get final price and balances
        uint256 finalPrice = btbExchange.getCurrentPrice();
        uint256 finalBTBY = btbToken.balanceOf(wallet);
        uint256 finalUSDC = usdcToken.balanceOf(wallet);
        uint256 finalExchangeBTBY = btbToken.balanceOf(exchange);

        vm.stopBroadcast();
    }
}
