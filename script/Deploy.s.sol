// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";
import "../src/BTBExchangeV1.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        
        // Deploy BTBYield with deployer as admin and minter
        BTBYield token = new BTBYield(deployer, deployer);
        console.log("BTBYield deployed at:", address(token));

        // Deploy BTBExchangeV1 with initial parameters
        address usdcAddress = address(0x0); // TODO: Replace with actual USDC address for the network
        uint256 buyFee = 100; // 1% buy fee
        uint256 sellFee = 100; // 1% sell fee
        BTBExchangeV1 exchange = new BTBExchangeV1(
            address(token),
            usdcAddress,
            buyFee,
            sellFee
        );
        console.log("BTBExchangeV1 deployed at:", address(exchange));

        // Grant minter role to exchange
        token.grantRole(token.MINTER_ROLE(), address(exchange));
        console.log("Minter role granted to exchange");

        vm.stopBroadcast();
    }
}