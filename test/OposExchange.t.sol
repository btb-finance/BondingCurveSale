// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {OPOSExchange} from "../src/OposExchange.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract OPOSExchangeTest is Test {
    OPOSExchange public oposZoo;
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
        oposZoo = new OPOSExchange(
            address(oposToken),
            address(usdc),
            zookeeper,
            foodCollector
        );
        
        // Give initial food supply
        usdc.mint(visitor1, FOOD_SUPPLY);
        usdc.mint(visitor2, FOOD_SUPPLY);
        
        // Put some opossums in the zoo
        oposToken.mint(address(oposZoo), 1000e18);
    }
    
    function test_ZooOpening() public {
        assertEq(address(oposZoo.token()), address(oposToken));
        assertEq(address(oposZoo.usdc()), address(usdc));
        assertEq(oposZoo.taxRecipient(), foodCollector);
        assertEq(oposZoo.feePercentage(), 1); // 1%
    }
    
    function test_OpossumPrices() public {
        // Check initial price
        assertEq(oposZoo.getOpossumsPerCoin(0, 0), 1e16); // 0.01 USDC
        
        // Add more opossums and check price changes
        oposToken.mint(address(oposZoo), 1000e18);
        assertTrue(oposZoo.getOpossumsPerCoin(1e6, 1000e18) > 1e16);
    }
    
    function test_CatchOpossum() public {
        uint256 foodAmount = 1e6; // 1 USDC
        uint256 expectedOpossums = oposZoo.howManyOpossums(foodAmount);
        
        vm.startPrank(visitor1);
        usdc.approve(address(oposZoo), foodAmount);
        oposZoo.catchOpossum(foodAmount);
        vm.stopPrank();
        
        assertEq(oposToken.balanceOf(visitor1), expectedOpossums);
        assertTrue(usdc.balanceOf(foodCollector) > 0); // Food collector got their share
    }
    
    function test_ReleaseOpossum() public {
        // First catch some opossums
        uint256 foodAmount = 1e6; // 1 USDC
        
        vm.startPrank(visitor1);
        usdc.approve(address(oposZoo), foodAmount);
        oposZoo.catchOpossum(foodAmount);
        
        // Now release half
        uint256 opossumCount = oposToken.balanceOf(visitor1) / 2;
        oposToken.approve(address(oposZoo), opossumCount);
        oposZoo.releaseOpossum(opossumCount);
        vm.stopPrank();
        
        assertEq(oposToken.balanceOf(visitor1), opossumCount);
    }
    
    function test_ZookeeperDuties() public {
        // Test teaching new tricks (setting fees)
        oposZoo.teachNewTrick(200); // 2%
        assertEq(oposZoo.feePercentage(), 200);
        
        // Test granting night vision (fee exclusion)
        oposZoo.grantNightVision(visitor1, true);
        assertTrue(oposZoo.isNightwalker(visitor1));
    }
    
    function testFail_TooManyTricks() public {
        oposZoo.teachNewTrick(1100); // 11% should fail
    }
    
    function testFail_UnauthorizedZookeeper() public {
        vm.prank(visitor1);
        oposZoo.teachNewTrick(200);
    }
    
    function test_PlayingDead() public {
        oposZoo.playDead(true);
        assertTrue(oposZoo.playingDead());
        
        vm.expectRevert("Opossum is playing dead");
        vm.prank(visitor1);
        oposZoo.catchOpossum(1e6);
    }
    
    function test_RaidingTrash() public {
        // First catch some opossums to get some USDC in the contract
        uint256 foodAmount = 1e6;
        vm.startPrank(visitor1);
        usdc.approve(address(oposZoo), foodAmount);
        oposZoo.catchOpossum(foodAmount);
        vm.stopPrank();
        
        // Now raid the trash (withdraw tokens)
        uint256 zookeeperInitialBalance = usdc.balanceOf(zookeeper);
        oposZoo.stealShinyCoins(1e5);
        assertTrue(usdc.balanceOf(zookeeper) > zookeeperInitialBalance);
    }
}
