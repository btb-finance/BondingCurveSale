// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBExchangeV1.sol";
import "../src/MockUSDC.sol";

contract BuyBTBYScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address usdc = 0x334f5A3ecC0c6dCea6d438a532B20dAe20806bC6;
        address exchange = 0x728EAE530d80E29a27074903775421A41eFd614A;
        
        // Get contract instances
        MockUSDC usdcToken = MockUSDC(usdc);
        BTBExchangeV1 btbExchange = BTBExchangeV1(exchange);
        
        // Approve USDC spending (1000 USDC with 6 decimals)
        uint256 approveAmount = 10000 * 10**6;
        usdcToken.approve(exchange, approveAmount);
        console.log("Approved USDC spending. Amount:", approveAmount);
        
        // Buy BTBY tokens with 100 USDC
        uint256 buyAmount = 1000 * 10**6;
        btbExchange.buyTokens(buyAmount);
        console.log("Bought BTBY tokens with USDC amount:", buyAmount);

        vm.stopBroadcast();
    }
}
