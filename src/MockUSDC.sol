// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MockUSDC is ERC20, ERC20Permit {
    constructor(address recipient)
        ERC20("USD Coin", "USDC")
        ERC20Permit("USD Coin")
    {
        _mint(recipient, 1000000 * 10 ** decimals()); // Mint 1M USDC
    }

    function decimals() public pure override returns (uint8) {
        return 6; // USDC uses 6 decimals
    }

    // Function to mint more USDC (for testing purposes)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
