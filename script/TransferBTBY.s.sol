// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract TransferBTBYScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address btbYield = 0x656e098E175c614BF14e9cE5a17736E25322920B;
        address exchange = 0xEed45965dd5DD2Fed4EA614fFA29cFF6CE974914;
        
        // Get the BTBYield contract instance
        BTBYield token = BTBYield(btbYield);
        
        // Transfer 1,000,000 tokens to exchange (with 18 decimals)
        uint256 amount = 1_000_000 * 10**18;
        token.transfer(exchange, amount);
        
        console.log("Transferred BTBY tokens to exchange. Amount:", amount);
        console.log("Exchange BTBY balance:", token.balanceOf(exchange));

        vm.stopBroadcast();
    }
}
