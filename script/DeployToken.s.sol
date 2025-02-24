// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract DeployTokenScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        
        // Deploy BTBYield with deployer as recipient of initial supply
        BTBYield token = new BTBYield(deployer);
        console.log("BTBYield deployed at:", address(token));

        vm.stopBroadcast();
    }
}
