// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";
import "../src/MockUSDC.sol";
import "../src/BTBExchangeV1.sol";

contract DeployAllScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        
        // Deploy MockUSDC
        MockUSDC usdc = new MockUSDC(deployer);
        console.log("MockUSDC deployed at:", address(usdc));
        
        // Deploy BTBYield
        BTBYield token = new BTBYield(deployer);
        console.log("BTBYield deployed at:", address(token));
        
        // Deploy BTBExchangeV1
        BTBExchangeV1 exchange = new BTBExchangeV1(
            address(token),  // BTBYield token
            address(usdc),   // USDC token
            deployer         // Admin address
        );
        console.log("BTBExchangeV1 deployed at:", address(exchange));
        
        // Fund the exchange with initial tokens
        uint256 initialTokenAmount = 100000 * 1e18; // 100,000 tokens
        token.approve(address(exchange), initialTokenAmount);
        
        // Fund the exchange with initial USDC
        uint256 initialUsdcAmount = 10000 * 1e6; // 10,000 USDC
        usdc.approve(address(exchange), initialUsdcAmount);
        
        // Transfer tokens to exchange
        token.transfer(address(exchange), initialTokenAmount);
        usdc.transfer(address(exchange), initialUsdcAmount);
        
        console.log("Exchange funded with:");
        console.log("- BTBYield:", initialTokenAmount / 1e18);
        console.log("- USDC:", initialUsdcAmount / 1e6);
        
        vm.stopBroadcast();
    }
}
