

# 🦝 Opossum Exchange - Self-Sustaining Bonding Curve

A decentralized token exchange implementing an innovative bonding curve mechanism that ensures continuous price appreciation through strategic token minting and burning.

## 🔄 Core Mechanics

### 1️⃣ Buy Mechanism (Token Minting)
- Users send USDC to the contract
- New tokens are minted directly to the buyer
- 1% fee is deducted in USDC
- Fee remains in contract, increasing price support

### 2️⃣ Sell Mechanism (Token Burning)
- Users send tokens back to contract
- Tokens are permanently burned
- Users receive USDC based on price formula
- 1% fee remains in contract

### 3️⃣ Price Formula
```
Price per token = (USDC balance in contract × 10^18) / (Total supply of OPOS)
```

## 📈 Price Appreciation Mechanics

The system ensures continuous price appreciation through:
1. **Buy Operations**
   - Add more USDC to contract
   - Mint proportionally fewer tokens (due to fee)
   - Increase USDC/token ratio

2. **Sell Operations**
   - Burn tokens (reduce supply)
   - Retain fee in contract
   - Maintain high liquidity

3. **Self-Sustaining Growth**
   - USDC balance grows over time
   - Token supply doesn't grow proportionally
   - Creates natural upward price movement

## 🛠 Technical Implementation

### Smart Contracts
- `OpossumToken.sol`: ERC20 token with minting and burning capabilities
- `OposExchange.sol`: Main exchange contract implementing bonding curve
- `LiquidityManager.sol`: Manages liquidity and fee distribution

### Key Features
- Modular design allowing multiple exchanges with same token
- Interface-based token integration
- Fee mechanism for sustainable growth
- Reentrancy protection
- Owner controls for emergency situations
