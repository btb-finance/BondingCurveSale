// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/OpossumToken.sol";
import "../src/OposExchange.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = 0x5e86890d3092204567e8d880afb51e1525f72cd434dac84d8daf7ea996964362;
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        // Deploy OpossumToken with deployer as admin and minter
        OpossumToken token = new OpossumToken(deployer, deployer);
        console.log("OpossumToken deployed at:", address(token));

        // Deploy OposExchange with initial parameters
        uint256 initialPrice = 1e16; // 0.01 ETH
        uint256 slope = 1e15;        // 0.001 ETH
        OposExchange exchange = new OposExchange(
            address(token),
            initialPrice,
            slope
        );
        console.log("OposExchange deployed at:", address(exchange));

        // Grant minter role to exchange
        token.grantRole(token.MINTER_ROLE(), address(exchange));
        console.log("Minter role granted to exchange");

        vm.stopBroadcast();
    }
}