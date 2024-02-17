// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixedPoint} from "./FixedPoint.sol";
import {FullMath} from "./FullMath.sol";
import {SafeCast} from "./SafeCast.sol";

/// @title LiquidityAmounts
/// @notice Provides functions for computing liquidity amounts from token amounts and prices
/// @dev implementation from https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/LiquidityAmounts.sol

library LiquidityAmounts {
	using SafeCast for uint256;

	function getLiquidityForAmount0(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint256 amount0
	) internal pure returns (uint128 liquidity) {
		if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

		uint256 intermediate = FullMath.mulDiv(sqrtRatioAX96, sqrtRatioBX96, FixedPoint.Q96);

		return FullMath.mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96).toUint128();
	}

	function getLiquidityForAmount1(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint256 amount1
	) internal pure returns (uint128 liquidity) {
		if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

		return FullMath.mulDiv(amount1, FixedPoint.Q96, sqrtRatioBX96 - sqrtRatioAX96).toUint128();
	}

	function getLiquidityForAmounts(
		uint160 sqrtRatioX96,
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint256 amount0,
		uint256 amount1
	) internal pure returns (uint128 liquidity) {
		if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

		if (sqrtRatioX96 <= sqrtRatioAX96) {
			liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
		} else if (sqrtRatioX96 < sqrtRatioBX96) {
			if (amount0 == 0) {
				liquidity = LiquidityAmounts.getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);
			} else if (amount1 == 0) {
				liquidity = LiquidityAmounts.getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
			} else {
				uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
				uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);

				liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
			}
		} else {
			liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
		}
	}

	function getAmount0ForLiquidity(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint128 liquidity
	) internal pure returns (uint256 amount0) {
		if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

		return
			FullMath.mulDiv(
				uint256(liquidity) << FixedPoint.RESOLUTION,
				sqrtRatioBX96 - sqrtRatioAX96,
				sqrtRatioBX96
			) / sqrtRatioAX96;
	}

	function getAmount1ForLiquidity(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint128 liquidity
	) internal pure returns (uint256 amount1) {
		if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

		return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint.Q96);
	}

	function getAmountsForLiquidity(
		uint160 sqrtRatioX96,
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint128 liquidity
	) internal pure returns (uint256 amount0, uint256 amount1) {
		if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

		if (sqrtRatioX96 <= sqrtRatioAX96) {
			amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
		} else if (sqrtRatioX96 < sqrtRatioBX96) {
			amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
			amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
		} else {
			amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
		}
	}
}
