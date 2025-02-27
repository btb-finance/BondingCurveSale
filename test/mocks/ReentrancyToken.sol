// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/BTBExchangeV1.sol";

contract ReentrancyToken is ERC20 {
    BTBExchangeV1 public exchange;
    bool public attackOnTransfer;
    bool public attackOnTransferFrom;
    uint256 public attackAmount;
    
    constructor() ERC20("Malicious Token", "EVIL") {
        _mint(msg.sender, 1_000_000e18);
    }
    
    function setExchange(address _exchange) external {
        exchange = BTBExchangeV1(_exchange);
    }
    
    function setAttackOnTransfer(bool _attack) external {
        attackOnTransfer = _attack;
    }
    
    function setAttackOnTransferFrom(bool _attack) external {
        attackOnTransferFrom = _attack;
    }
    
    function setAttackAmount(uint256 _amount) external {
        attackAmount = _amount;
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        
        // Attempt reentrancy attack on transfer
        if (attackOnTransfer && to == address(exchange)) {
            exchange.sellTokens(attackAmount);
        }
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        bool result = super.transferFrom(from, to, amount);
        
        // Attempt reentrancy attack on transferFrom
        if (attackOnTransferFrom && to == address(exchange)) {
            exchange.sellTokens(attackAmount);
        }
        
        return result;
    }
}
