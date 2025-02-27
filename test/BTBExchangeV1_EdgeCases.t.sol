// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {BTBExchangeV1} from "../src/BTBExchangeV1.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "./BTBExchangeV1.t.sol";

// Custom ERC20 with transfer fee for testing
contract FeeToken is MockERC20 {
    uint256 public fee = 100; // 1% fee (out of 10000)
    
    constructor(string memory name, string memory symbol, uint8 decimals) 
        MockERC20(name, symbol, decimals) {}
    
    function setFee(uint256 _fee) external {
        fee = _fee;
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 feeAmount = (amount * fee) / 10000;
        uint256 netAmount = amount - feeAmount;
        
        // Burn the fee
        _burn(msg.sender, feeAmount);
        return super.transfer(to, netAmount);
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // Deduct allowance first
        _spendAllowance(from, msg.sender, amount);
        
        uint256 feeAmount = (amount * fee) / 10000;
        uint256 netAmount = amount - feeAmount;
        
        // Burn the fee
        _burn(from, feeAmount);
        // Transfer the net amount
        _transfer(from, to, netAmount);
        
        return true;
    }
}

contract BTBExchangeV1EdgeCasesTest is BTBExchangeV1Test {
    
    function setUp() public override {
        super.setUp();
        
        // Approve tokens for all tests
        _approveTokens(user1, type(uint256).max, type(uint256).max);
        _approveTokens(user2, type(uint256).max, type(uint256).max);
    }
    
    function test_MinimumPrice() public {
        // Create a new exchange with very low reserves
        vm.startPrank(owner);
        MockERC20 newToken = new MockERC20("Low Reserve Token", "LRT", 18);
        MockERC20 newUsdc = new MockERC20("Low Reserve USDC", "LRUSDC", 6);
        
        BTBExchangeV1 lowReserveExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        // Add minimal tokens to exchange
        newToken.mint(address(lowReserveExchange), 1e18); // 1 token
        newUsdc.mint(address(lowReserveExchange), 1e6);   // 1 USDC
        
        // Create circulation
        newToken.mint(address(0x1), 1e17);
        
        // Check price (should be minimum price)
        uint256 price = lowReserveExchange.getCurrentPrice();
        assertEq(price, MIN_PRICE);
        
        // Mint tokens for user1
        newToken.mint(user1, 100e18);
        newUsdc.mint(user1, 100e6);
        
        // Approve tokens
        vm.stopPrank();
        
        vm.startPrank(user1);
        newToken.approve(address(lowReserveExchange), type(uint256).max);
        newUsdc.approve(address(lowReserveExchange), type(uint256).max);
        
        // Buy tokens - should work at minimum price
        uint256 usdcAmount = 10e6;
        uint256 tokenBalanceBefore = newToken.balanceOf(user1);
        
        lowReserveExchange.buyTokens(usdcAmount);
        
        uint256 tokenBalanceAfter = newToken.balanceOf(user1);
        uint256 tokensBought = tokenBalanceAfter - tokenBalanceBefore;
        
        // Verify tokens were received
        assertTrue(tokensBought > 0);
        
        // Price should still be at or near minimum
        uint256 priceAfterBuy = lowReserveExchange.getCurrentPrice();
        assertTrue(priceAfterBuy >= MIN_PRICE);
        
        vm.stopPrank();
    }
    
    function test_ZeroCirculation() public {
        // Create a new exchange with zero circulation
        vm.startPrank(owner);
        MockERC20 newToken = new MockERC20("Zero Circ Token", "ZCT", 18);
        MockERC20 newUsdc = new MockERC20("Zero Circ USDC", "ZCUSDC", 6);
        
        BTBExchangeV1 zeroCircExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        // Add tokens to exchange but don't create any circulation
        newToken.mint(address(zeroCircExchange), 1000000e18);
        newUsdc.mint(address(zeroCircExchange), 100000e6);
        
        // Mint tokens for user1
        newToken.mint(user1, 100000e18);
        newUsdc.mint(user1, 100000e6);
        
        // Approve tokens
        vm.stopPrank();
        
        vm.startPrank(user1);
        newToken.approve(address(zeroCircExchange), type(uint256).max);
        newUsdc.approve(address(zeroCircExchange), type(uint256).max);
        
        // Buy tokens - should create circulation
        uint256 usdcAmount = 1000e6;
        uint256 tokenBalanceBefore = newToken.balanceOf(user1);
        
        zeroCircExchange.buyTokens(usdcAmount);
        
        uint256 tokenBalanceAfter = newToken.balanceOf(user1);
        uint256 tokensBought = tokenBalanceAfter - tokenBalanceBefore;
        
        // Verify tokens were received
        assertTrue(tokensBought > 0);
        
        // Check circulation
        uint256 circulation = newToken.totalSupply() - newToken.balanceOf(address(zeroCircExchange));
        assertTrue(circulation > 0);
        assertTrue(circulation >= MIN_EFFECTIVE_CIRCULATION);
        
        vm.stopPrank();
    }
    
    function test_BuyWithFeeToken() public {
        // Create a new exchange with a token that has transfer fees
        vm.startPrank(owner);
        FeeToken feeToken = new FeeToken("Fee Token", "FEE", 18);
        MockERC20 feeUsdc = new MockERC20("Fee USDC", "FUSDC", 6);
        
        BTBExchangeV1 feeExchange = new BTBExchangeV1(
            address(feeToken),
            address(feeUsdc),
            admin
        );
        
        // Add tokens to exchange
        feeToken.mint(address(feeExchange), 1000000e18);
        feeUsdc.mint(address(feeExchange), 100000e6);
        
        // Create circulation
        feeToken.mint(address(0x1), 1e17);
        
        // Mint tokens for user1
        feeToken.mint(user1, 100000e18);
        feeUsdc.mint(user1, 100000e6);
        
        // Approve tokens
        vm.stopPrank();
        
        vm.startPrank(user1);
        feeToken.approve(address(feeExchange), type(uint256).max);
        feeUsdc.approve(address(feeExchange), type(uint256).max);
        
        // Buy tokens - should work despite the fee
        uint256 usdcAmount = 1000e6;
        uint256 tokenBalanceBefore = feeToken.balanceOf(user1);
        
        feeExchange.buyTokens(usdcAmount);
        
        uint256 tokenBalanceAfter = feeToken.balanceOf(user1);
        uint256 tokensBought = tokenBalanceAfter - tokenBalanceBefore;
        
        // Verify tokens were received (less than quoted due to fee)
        assertTrue(tokensBought > 0);
        
        // Check that the fee was applied
        (uint256 quotedTokens,,, ) = feeExchange.quoteTokensForUsdc(usdcAmount);
        assertTrue(tokensBought < quotedTokens);
        
        vm.stopPrank();
    }
    
    function test_SellWithFeeToken() public {
        // Create a new exchange with a token that has transfer fees
        vm.startPrank(owner);
        FeeToken feeToken = new FeeToken("Fee Token", "FEE", 18);
        MockERC20 feeUsdc = new MockERC20("Fee USDC", "FUSDC", 6);
        
        BTBExchangeV1 feeExchange = new BTBExchangeV1(
            address(feeToken),
            address(feeUsdc),
            admin
        );
        
        // Add tokens to exchange
        feeToken.mint(address(feeExchange), 1000000e18);
        feeUsdc.mint(address(feeExchange), 100000e6);
        
        // Create circulation
        feeToken.mint(address(0x1), 1e17);
        
        // Mint tokens for user1
        feeToken.mint(user1, 100000e18);
        feeUsdc.mint(user1, 100000e6);
        
        // Approve tokens
        vm.stopPrank();
        
        vm.startPrank(user1);
        feeToken.approve(address(feeExchange), type(uint256).max);
        feeUsdc.approve(address(feeExchange), type(uint256).max);
        
        // Sell tokens - should receive less USDC due to token fee
        uint256 tokenAmount = 1000e18;
        uint256 usdcBalanceBefore = feeUsdc.balanceOf(user1);
        
        feeExchange.sellTokens(tokenAmount);
        
        uint256 usdcBalanceAfter = feeUsdc.balanceOf(user1);
        uint256 usdcReceived = usdcBalanceAfter - usdcBalanceBefore;
        
        // Verify USDC was received
        assertTrue(usdcReceived > 0);
        
        // Check that the fee was applied
        (uint256 quotedUsdc,,, ) = feeExchange.quoteUsdcForTokens(tokenAmount);
        assertTrue(usdcReceived < quotedUsdc);
        
        vm.stopPrank();
    }
    
    function test_ExtremelySmallTrades() public {
        // Try extremely small buy
        uint256 tinyUsdcAmount = 1; // 0.000001 USDC (smallest unit)
        
        vm.startPrank(user1);
        
        // Should revert due to minimum trade size or precision issues
        vm.expectRevert();
        exchange.buyTokens(tinyUsdcAmount);
        
        // Try extremely small sell
        uint256 tinyTokenAmount = 1; // 0.000000000000000001 token (smallest unit)
        
        // Should revert due to minimum trade size or precision issues
        vm.expectRevert();
        exchange.sellTokens(tinyTokenAmount);
        
        vm.stopPrank();
    }
    
    function test_ExtremelyLargeTrades() public {
        // Try extremely large buy (more than available USDC)
        uint256 hugeUsdcAmount = 1000000000e6; // 1 billion USDC
        
        vm.startPrank(user1);
        usdcToken.mint(user1, hugeUsdcAmount);
        usdcToken.approve(address(exchange), hugeUsdcAmount);
        
        // Should revert due to insufficient tokens in exchange
        vm.expectRevert();
        exchange.buyTokens(hugeUsdcAmount);
        
        // Try extremely large sell (more than available tokens)
        uint256 hugeTokenAmount = 1000000000e18; // 1 billion tokens
        
        btbToken.mint(user1, hugeTokenAmount);
        btbToken.approve(address(exchange), hugeTokenAmount);
        
        // Should revert due to insufficient USDC in exchange
        vm.expectRevert();
        exchange.sellTokens(hugeTokenAmount);
        
        vm.stopPrank();
    }
    
    function test_ZeroTokenBalance() public {
        // Create a new exchange with zero tokens
        vm.startPrank(owner);
        MockERC20 newToken = new MockERC20("Zero Token", "ZT", 18);
        MockERC20 newUsdc = new MockERC20("Zero Token USDC", "ZTUSDC", 6);
        
        BTBExchangeV1 zeroTokenExchange = new BTBExchangeV1(
            address(newToken),
            address(newUsdc),
            admin
        );
        
        // Add only USDC to exchange
        newUsdc.mint(address(zeroTokenExchange), 100000e6);
        
        // Create circulation
        newToken.mint(address(0x1), 1e17);
        
        // Mint tokens for user1
        newToken.mint(user1, 100000e18);
        newUsdc.mint(user1, 100000e6);
        
        // Approve tokens
        vm.stopPrank();
        
        vm.startPrank(user1);
        newToken.approve(address(zeroTokenExchange), type(uint256).max);
        newUsdc.approve(address(zeroTokenExchange), type(uint256).max);
        
        // Try to buy tokens - should revert due to insufficient tokens
        vm.expectRevert();
        zeroTokenExchange.buyTokens(1000e6);
        
        vm.stopPrank();
    }
}
