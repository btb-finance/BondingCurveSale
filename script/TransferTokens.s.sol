// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/BTBYield.sol";

contract TransferTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address exchangeAddress = 0x1cEE9Bd2bdCD04e3880a51210AC78F5D70DD1B9B;
        BTBYield token = BTBYield(0xAF36A1B261e42946F47B6eEd24db5478E9b46F16);
        
        // Get deployer's balance
        address deployer = vm.addr(deployerPrivateKey);
        uint256 balance = token.balanceOf(deployer);
        
        // Transfer all tokens to exchange
        token.transfer(exchangeAddress, balance);
        console.log("Transferred tokens to exchange:", balance);

        vm.stopBroadcast();
    }
}
