// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/MockUSDC.sol";

contract ApproveUSDCScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchangeAddress = 0x1cEE9Bd2bdCD04e3880a51210AC78F5D70DD1B9B;
        MockUSDC usdc = MockUSDC(0xE5c212De64a5481E719d7c6ee8d00F2Cb9a20864);
        
        // Approve a large amount for testing
        uint256 approvalAmount = 1_000_000 * 10**6; // 1 million USDC
        usdc.approve(exchangeAddress, approvalAmount);
        console.log("Approved USDC spending:", approvalAmount);

        vm.stopBroadcast();
    }
}
