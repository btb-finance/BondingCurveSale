// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @custom:security-contact hello@BTB.finance
contract BTBYield is ERC20, ERC20Permit {
    constructor() ERC20("BTB Yield", "BTBY") ERC20Permit("BTB Yield") {}
}