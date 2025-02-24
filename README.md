

# 🦝 Opossum Exchange - Self-Sustaining Bonding Curve

## 📄 Deployed Contract Addresses (Optimism Sepolia)

- OpossumToken: `0x2474822beCb1E16aAC52DD29281C5EcB32787189`
- OposExchange: `0xF4eA7d40623F51833956954bB55BDc108C1e79B5`

## 🚀 Quick Start

### Prerequisites

1. Install [Git](https://git-scm.com/downloads)
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/BondingCurveSale.git
cd BondingCurveSale
```

2. Install dependencies:
```bash
forge install
```

3. Create a `.env` file in the root directory and add your configuration:
```env
OPTIMISM_SEPOLIA_RPC_URL="https://sepolia.optimism.io"
ETHERSCAN_API_KEY="your-etherscan-api-key"
PRIVATE_KEY="your-private-key-without-0x-prefix"
OPTIMISM_ETHERSCAN_API_KEY="your-optimism-etherscan-api-key"
```

## 🛠 Development Commands

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
forge script script/Deploy.s.sol --rpc-url optimism_sepolia --broadcast
```

## 🏗 Technical Implementation

### Smart Contracts

- `OpossumToken.sol`: ERC20 token with minting and burning capabilities
- `OposExchange.sol`: Main exchange contract implementing bonding curve
- `LiquidityManager.sol`: Manages liquidity and fee distribution

## 📝 License

This project is licensed under the MIT License.
