// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";

abstract contract Utils {
	using FullMath for uint256;
	using PercentageMath for uint256;
	using WadRayMath for uint256;

	function getSupplyAndBorrowAmounts(
		uint256 collateralPrice,
		uint256 collateralUnit,
		uint256 borrowPrice,
		uint256 borrowUnit,
		uint256 ltv,
		uint256 collateralUsage,
		uint256 collateralInETH
	) internal pure returns (uint256 supplyAmount, uint256 borrowAmount) {
		supplyAmount = convertFromETH(collateralInETH, collateralPrice, collateralUnit);

		borrowAmount = convertFromETH(
			collateralInETH.percentMul(ltv).percentMul(collateralUsage),
			borrowPrice,
			borrowUnit
		);
	}

	function getRepayAndRedeemAmounts(
		uint256 supplyBalance,
		uint256 collateralPrice,
		uint256 collateralUnit,
		uint256 borrowBalance,
		uint256 borrowPrice,
		uint256 borrowUnit,
		uint256 ltv,
		uint256 collateralUsage,
		uint256 debtRatio
	) internal pure returns (uint256 repayAmount, uint256 redeemAmount) {
		repayAmount = borrowBalance.percentMul(debtRatio);

		uint256 borrowValue = convertToETH(borrowBalance - repayAmount, borrowPrice, borrowUnit);

		uint256 collateralValue = convertToETH(supplyBalance, collateralPrice, collateralUnit);

		collateralValue -= borrowValue.percentDiv(collateralUsage).percentDiv(ltv);

		redeemAmount = convertFromETH(collateralValue, collateralPrice, collateralUnit);
	}

	function convertFromETH(uint256 amount, uint256 price, uint256 unit) internal pure returns (uint256) {
		return amount.mulDiv(toScale(unit), price);
	}

	function convertToETH(uint256 amount, uint256 price, uint256 unit) internal pure returns (uint256) {
		return amount.mulDiv(price, toScale(unit));
	}

	function derivePrice(
		uint256 baseAnswer,
		uint256 quoteAnswer,
		uint8 baseDecimals,
		uint8 quoteDecimals,
		uint8 assetDecimals
	) internal pure returns (uint256) {
		if (baseAnswer == 0 || quoteAnswer == 0) return 0;

		return
			FullMath.mulDiv(
				scalePrice(baseAnswer, baseDecimals, assetDecimals),
				toScale(assetDecimals),
				scalePrice(quoteAnswer, quoteDecimals, assetDecimals)
			);
	}

	function invertPrice(
		uint256 answer,
		uint8 baseDecimals,
		uint8 quoteDecimals
	) internal pure returns (uint256 inverted) {
		assembly ("memory-safe") {
			if gt(answer, 0x00) {
				inverted := div(exp(10, add(baseDecimals, quoteDecimals)), answer)
			}
		}
	}

	function scalePrice(
		uint256 answer,
		uint8 feedDecimals,
		uint8 assetDecimals
	) internal pure returns (uint256 scaled) {
		assembly ("memory-safe") {
			switch or(iszero(answer), eq(feedDecimals, assetDecimals))
			case 0x00 {
				switch gt(feedDecimals, assetDecimals)
				case 0x00 {
					scaled := mul(answer, exp(10, sub(assetDecimals, feedDecimals)))
				}
				default {
					scaled := div(answer, exp(10, sub(feedDecimals, assetDecimals)))
				}
			}
			default {
				scaled := answer
			}
		}
	}

	function toScale(uint256 unit) internal pure returns (uint256) {
		unchecked {
			return 10 ** unit;
		}
	}
}
