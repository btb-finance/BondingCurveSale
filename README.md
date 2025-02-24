# 🏦 BTB Finance - Dynamic USDC Bonding Curve Exchange

## 📄 Overview

BTB Finance implements a dynamic bonding curve exchange system where users can trade BTB Yield tokens (BTBY) against USDC. The system uses a unique price discovery mechanism based on the total USDC raised and circulating supply.

## 🏗 Smart Contracts

### BTBYield Token (BTBY)
- ERC20 token with ERC20Permit functionality for gasless approvals
- Implements role-based access control for minting
- Secure and auditable token management

### BTBExchangeV1
- Implements a dynamic USDC-based bonding curve
- Features:
  - Automatic price discovery based on total USDC raised and circulating supply
  - Buy and sell functionality with customizable fees
  - Anti-manipulation protections (single block trade prevention)
  - Minimum price protection (1 USDC)
  - Emergency pause mechanism
  - Fee management system
  - Secure withdrawal functions for owner

## 🔒 Security Features

1. **Price Protection**
   - Minimum price of 1 USDC
   - Protection against division by zero
   - Gradual price discovery mechanism

2. **Anti-Manipulation**
   - Single block trade prevention
   - Reentrancy protection
   - Emergency pause functionality

3. **Access Control**
   - Role-based token minting
   - Owner-only fee management
   - Secure withdrawal system

## 🚀 Quick Start

### Prerequisites

1. Install [Git](https://git-scm.com/downloads)
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. Install [pnpm](https://pnpm.io/installation)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/BondingCurveSale.git
cd BondingCurveSale
```

2. Install dependencies:
```bash
pnpm install
forge install
```

3. Create a `.env` file:
```env
PRIVATE_KEY="your-private-key-without-0x-prefix"
ETHERSCAN_API_KEY="your-etherscan-api-key"
```

## 💻 Development Commands

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Deploy
```bash
forge script script/Deploy.s.sol --rpc-url <your-rpc-url> --broadcast
```

## 📊 Exchange Mechanics

### Price Discovery
The price is calculated using the formula:
```
Price = (Total USDC Raised) / (Total Supply - Contract's Token Balance)
```

### Fees
- Buy and sell fees are customizable (in basis points)
- Fees contribute to the total USDC raised, creating price appreciation for holders
- Default fees are set to 1% (100 basis points)

## 🔐 Security Considerations

1. **For Users**
   - Check current price before trading
   - Be aware of price impact for large trades
   - Verify token and USDC addresses

2. **For Integrators**
   - Use the view functions to calculate expected amounts
   - Handle potential revert cases
   - Implement proper slippage protection

## 📝 License

This project is licensed under the MIT License.
