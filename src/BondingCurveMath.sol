// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title BondingCurveMath
 * @dev Provides closed-form calculations for the 1% step bonding curve:
 *      Cost(x) = P0 * (1.01^N) * [ (1.01^x) - 1 ] / 0.01
 *      Payout(x) = P0 * (1.01^(N - x)) * [ (1.01^x) - 1 ] / 0.01
 *
 * Also demonstrates a simplified fixed-point exponent approach for (1.01^value).
 */
library BondingCurveMath {
    // We'll store 1.01 as a fixed-point number with 18 decimals: 1.01 * 1e18 = 1010000000000000000
    uint256 public constant ONE_POINT_ZERO_ONE = 1010000000000000000; // 1.01 in 1e18
    uint256 public constant ONE_IN_WEI = 1e18;                       // 1.0 in 1e18
    uint256 public constant FEE_DENOM = 1e4;                         // for basis points (BP)

    /**
     * @notice Approximates (1.01^exponent) in 1e18 fixed-point arithmetic.
     * @dev This uses exponentiation by squaring with a constant base of 1.01 (scaled to 1e18).
     *      In reality, for large exponents, consider log-based methods or specialized libraries.
     * @param exponent Scaled by 1e18 if you want fractional exponents; integer if only whole tokens.
     */
    function pow1p01(uint256 exponent) public pure returns (uint256) {
        // For simplicity, we treat exponent as an integer (no fractional tokens).
        // If you allow fractional tokens, you'd need a more advanced approach (logs, PRBMath, etc.).

        // exponent is how many tokens (no decimal). We'll do a quick loop for demonstration,
        // but be aware this can be expensive for huge exponent values.
        // For large scale usage, implement a more efficient method or limit maximum exponent.
        uint256 result = ONE_IN_WEI;
        uint256 base = ONE_POINT_ZERO_ONE;

        // Exponentiation by squaring approach, but we treat `exponent` as a normal uint. 
        // If exponent is enormous, you can run into large loops or overflow.
        uint256 e = exponent; 
        while (e > 0) {
            if ((e & 1) == 1) {
                result = (result * base) / ONE_IN_WEI;
            }
            base = (base * base) / ONE_IN_WEI;
            e >>= 1;
        }
        return result;
    }

    /**
     * @notice Get current token price based on number of tokens sold
     * @param basePrice Initial price in wei
     * @param netTokensSold Number of tokens sold
     * @return Current token price in wei
     */
    function getCurrentPrice(uint256 basePrice, uint256 netTokensSold) public pure returns (uint256) {
        if (netTokensSold == 0) return basePrice;
        return (basePrice * pow1p01(netTokensSold)) / ONE_IN_WEI;
    }

    /**
     * @notice Computes the cost (in wei) to buy `x` tokens from the bonding curve
     * @param basePrice  P0 in wei
     * @param N          Current net tokens sold (integer, no decimals)
     * @param x          Number of tokens to buy in this transaction
     * @return cost      The raw cost (without the buy fee) in wei
     */
    function buyCost(
        uint256 basePrice,
        uint256 N,
        uint256 x
    ) external pure returns (uint256 cost) {
        // cost(x) = P0 * (1.01^N) * [ (1.01^x) - 1 ] / 0.01
        // We'll approximate 0.01 as (1.01 - 1.0) in 1e18 => 0.01 * 1e18 = 10000000000000000
        // Steps:
        //   A = (1.01^N)
        //   B = (1.01^x) - 1
        //   cost = basePrice * A * B / 0.01
        // all in 1e18 scale.

        uint256 AN = pow1p01(N);  // (1.01^N)
        uint256 AX = pow1p01(x);  // (1.01^x)
        // B = AX - 1e18 (since AX is in 1e18 scale)
        uint256 B = AX > ONE_IN_WEI ? (AX - ONE_IN_WEI) : 0;

        // cost = basePrice * AN * B / 0.01_in_1e18
        // 0.01 in 1e18 = 0.01 * 1e18 = 10_000_000_000_000_000
        uint256 scale = 10_000_000_000_000_000; // 0.01 * 1e18
        cost = (basePrice * AN) / ONE_IN_WEI;
        cost = (cost * B) / ONE_IN_WEI;
        cost = (cost * ONE_IN_WEI) / scale; // dividing by 0.01
    }

    /**
     * @notice Computes the payout (in wei) when selling `x` tokens to the bonding curve
     * @param basePrice P0 in wei
     * @param N         Current net tokens sold (integer, no decimals)
     * @param x         Number of tokens to sell
     * @return payout   The raw payout (without the sell fee) in wei
     */
    function sellPayout(
        uint256 basePrice,
        uint256 N,
        uint256 x
    ) external pure returns (uint256 payout) {
        // Sell formula:
        //   sum_{i = N-x to N-1} [ P0 * (1.01^i ) ]
        //   = P0 * (1.01^(N-x)) * [ (1.01^x) - 1 ] / 0.01
        //
        // We do:
        //   ANx = (1.01)^(N - x)
        //   AX = (1.01^x) - 1
        //   payout = basePrice * ANx * AX / 0.01

        uint256 ANx = pow1p01(N - x); 
        uint256 AX  = pow1p01(x);
        uint256 B = AX > ONE_IN_WEI ? (AX - ONE_IN_WEI) : 0;

        uint256 scale = 10_000_000_000_000_000; // 0.01 in 1e18
        payout = (basePrice * ANx) / ONE_IN_WEI;
        payout = (payout * B) / ONE_IN_WEI;
        payout = (payout * ONE_IN_WEI) / scale;
    }
}
