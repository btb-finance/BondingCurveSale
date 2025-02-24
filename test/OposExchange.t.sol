// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {OposExchange} from "../src/OposExchange.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract OposExchangeTest is Test {
    OposExchange public oposZoo;
    MockERC20 public oposToken;
    MockERC20 public usdc;
    
    address public zookeeper;
    address public foodCollector;
    address public visitor1;
    address public visitor2;
    
    uint256 public constant FOOD_SUPPLY = 1000000e6; // 1M USDC
    
    function setUp() public {
        zookeeper = address(this);
        foodCollector = makeAddr("foodCollector");
        visitor1 = makeAddr("visitor1");
        visitor2 = makeAddr("visitor2");
        
        // Deploy tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        oposToken = new MockERC20("OPOSSUM", "OPOS", 18);
        
        // Deploy zoo
        oposZoo = new OposExchange(
            address(oposToken),
            1e16, // Initial price 0.01 ETH
            1e15  // Slope
        );
        
        // Give initial food supply
        usdc.mint(visitor1, FOOD_SUPPLY);
        usdc.mint(visitor2, FOOD_SUPPLY);
        
        // Put some opossums in the zoo
        oposToken.mint(address(oposZoo), 1000e18);
    }
    
    function test_ZooOpening() public {
        assertEq(address(oposZoo.token()), address(oposToken));
        assertEq(oposZoo.initialPrice(), 1e16);
        assertEq(oposZoo.slope(), 1e15);
    }
    
    function test_OpossumPrices() public {
        // Check initial price
        assertEq(oposZoo.getCurrentPrice(), 1e16); // 0.01 ETH
        
        // Add more opossums and check price changes
        oposToken.mint(address(oposZoo), 1000e18);
        oposZoo.buyTokens{value: 1 ether}();
        assertTrue(oposZoo.getCurrentPrice() > 1e16);
    }
    
    function test_BuyTokens() public {
        uint256 ethAmount = 1 ether;
        uint256 expectedTokens = oposZoo.getTokenAmount(ethAmount);
        
        vm.startPrank(visitor1);
        oposZoo.buyTokens{value: ethAmount}();
        vm.stopPrank();
        
        assertEq(oposToken.balanceOf(visitor1), expectedTokens);
        assertEq(address(oposZoo).balance, ethAmount);
    }
    
    function test_SellTokens() public {
        // First buy some tokens
        uint256 ethAmount = 1 ether;
        
        vm.startPrank(visitor1);
        oposZoo.buyTokens{value: ethAmount}();
        
        // Now sell half
        uint256 tokenAmount = oposToken.balanceOf(visitor1) / 2;
        oposToken.approve(address(oposZoo), tokenAmount);
        uint256 initialBalance = address(visitor1).balance;
        oposZoo.sellTokens(tokenAmount);
        vm.stopPrank();
        
        assertEq(oposToken.balanceOf(visitor1), tokenAmount);
        assertTrue(address(visitor1).balance > initialBalance);
    }
    
    function test_PriceParams() public {
        uint256 newInitialPrice = 2e16;
        uint256 newSlope = 2e15;
        
        vm.startPrank(oposZoo.owner());
        oposZoo.updatePriceParams(newInitialPrice, newSlope);
        vm.stopPrank();
        
        assertEq(oposZoo.initialPrice(), newInitialPrice);
        assertEq(oposZoo.slope(), newSlope);
    }
    

}
