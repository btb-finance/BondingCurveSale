// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract ApproveBTBScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchangeAddress = 0x1cEE9Bd2bdCD04e3880a51210AC78F5D70DD1B9B;
        BTBYield btb = BTBYield(0xAF36A1B261e42946F47B6eEd24db5478E9b46F16);
        
        // Approve a large amount for testing
        uint256 approvalAmount = 1_000_000 * 10**18; // 1 million BTB
        btb.approve(exchangeAddress, approvalAmount);
        console.log("Approved BTB spending:", approvalAmount);

        vm.stopBroadcast();
    }
}
