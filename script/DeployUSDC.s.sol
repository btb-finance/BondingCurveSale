// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/MockUSDC.sol";

contract DeployUSDCScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        
        // Deploy MockUSDC with deployer as recipient of initial supply
        MockUSDC usdc = new MockUSDC(deployer);
        console.log("MockUSDC deployed at:", address(usdc));

        vm.stopBroadcast();
    }
}
