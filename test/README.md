# BTBExchangeV1 Test Suite

This directory contains a comprehensive test suite for the BTBExchangeV1 contract. The tests are organized into multiple files, each focusing on a specific aspect of the contract's functionality.

## Test Structure

The test suite is organized as follows:

1. **BTBExchangeV1.t.sol**: Base test contract with common setup and helper functions.
2. **BTBExchangeV1_Deployment.t.sol**: Tests for contract deployment scenarios.
3. **BTBExchangeV1_PriceCalculation.t.sol**: Tests for price calculation under various conditions.
4. **BTBExchangeV1_Fees.t.sol**: Tests for fee calculations and updates.
5. **BTBExchangeV1_Trading.t.sol**: Tests for buying and selling tokens.
6. **BTBExchangeV1_Admin.t.sol**: Tests for admin functions like updating admin address and pausing.
7. **BTBExchangeV1_Borrowing.t.sol**: Tests for borrowing and repaying USDC.
8. **BTBExchangeV1_Security.t.sol**: Tests for security features like reentrancy protection.
9. **BTBExchangeV1_Integration.t.sol**: Integration tests for sequences of operations.
10. **BTBExchangeV1_EdgeCases.t.sol**: Tests for edge cases and unusual scenarios.

## Mock Contracts

The `mocks` directory contains helper contracts for testing:

1. **MockERC20.sol**: A simple ERC20 token implementation for testing.
2. **ReentrancyToken.sol**: A malicious token that attempts reentrancy attacks.
3. **FeeToken.sol**: A token that charges fees on transfers.

## Running Tests

To run all tests:

```bash
pnpm forge test
```

To run a specific test file:

```bash
pnpm forge test --match-path test/BTBExchangeV1_Trading.t.sol
```

To run a specific test function:

```bash
pnpm forge test --match-test test_BuyTokens
```

To run tests with verbose output:

```bash
pnpm forge test -vv
```

## Test Coverage

The test suite aims to provide comprehensive coverage of the BTBExchangeV1 contract, including:

1. **Deployment Tests**: Valid and invalid deployment scenarios.
2. **Price Calculation Tests**: Testing price calculation under various conditions.
3. **Fee Tests**: Verifying fee calculations and updates.
4. **Trading Tests**: Testing buying and selling tokens.
5. **Admin Function Tests**: Testing admin functions like updating admin address.
6. **Borrowing/Repayment Tests**: Testing USDC borrowing and repayment.
7. **Security Tests**: Testing for reentrancy, access control, and other security concerns.
8. **Integration Tests**: Testing sequences of operations.
9. **Edge Cases**: Testing unusual scenarios and extreme values.

## Gas Usage

Some tests include gas usage measurements to help optimize the contract's efficiency. Look for `console2.log` statements in the test files for gas usage information.
