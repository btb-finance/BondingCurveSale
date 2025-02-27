// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

contract BTBExchangeV1DeploymentTest is BTBExchangeV1Test {
    
    function test_DeploymentWithValidAddresses() public {
        BTBExchangeV1 newExchange = new BTBExchangeV1(
            address(btbToken),
            address(usdcToken),
            admin
        );
        
        assertEq(address(newExchange.token()), address(btbToken));
        assertEq(address(newExchange.usdc()), address(usdcToken));
        assertEq(newExchange.adminAddress(), admin);
        assertEq(newExchange.usdcBorrowed(), 0);
        assertEq(newExchange.owner(), address(this));
    }
    
    function testFail_DeploymentWithZeroTokenAddress() public {
        new BTBExchangeV1(
            address(0),
            address(usdcToken),
            admin
        );
    }
    
    function testFail_DeploymentWithZeroUsdcAddress() public {
        new BTBExchangeV1(
            address(btbToken),
            address(0),
            admin
        );
    }
    
    function testFail_DeploymentWithZeroAdminAddress() public {
        new BTBExchangeV1(
            address(btbToken),
            address(usdcToken),
            address(0)
        );
    }
    
    function test_InitialStateVariables() public {
        assertEq(exchange.buyFee(), 30);
        assertEq(exchange.sellFee(), 30);
        assertEq(exchange.adminFee(), 10);
        assertEq(exchange.usdcBorrowed(), 0);
    }
    
    function test_Constants() public {
        assertEq(exchange.PRECISION(), 1e6);
        assertEq(exchange.TOKEN_PRECISION(), 1e18);
        assertEq(exchange.FEE_PRECISION(), 10000);
        assertEq(exchange.MIN_PRICE(), 10000);
        assertEq(exchange.MIN_EFFECTIVE_CIRCULATION(), 1e16);
        assertEq(exchange.MAX_INITIAL_PRICE(), 100000);
    }
}
