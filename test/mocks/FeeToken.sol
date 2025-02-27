// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeToken is ERC20 {
    uint256 public transferFeePercent;
    address public feeCollector;
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 _transferFeePercent
    ) ERC20(name, symbol) {
        transferFeePercent = _transferFeePercent;
        feeCollector = msg.sender;
        _mint(msg.sender, 1_000_000e18);
    }
    
    function setFeeCollector(address _feeCollector) external {
        require(msg.sender == feeCollector, "Only fee collector can change");
        feeCollector = _feeCollector;
    }
    
    function setTransferFeePercent(uint256 _transferFeePercent) external {
        require(msg.sender == feeCollector, "Only fee collector can change");
        require(_transferFeePercent <= 100, "Fee too high");
        transferFeePercent = _transferFeePercent;
    }
    
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (transferFeePercent > 0) {
            uint256 feeAmount = (amount * transferFeePercent) / 100;
            uint256 transferAmount = amount - feeAmount;
            
            super._transfer(sender, feeCollector, feeAmount);
            super._transfer(sender, recipient, transferAmount);
        } else {
            super._transfer(sender, recipient, amount);
        }
    }
    
    function mint(address to, uint256 amount) external {
        require(msg.sender == feeCollector, "Only fee collector can mint");
        _mint(to, amount);
    }
}
