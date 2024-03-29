// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency} from "src/types/Currency.sol";

abstract contract Common {
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

	function latestAnswer(address feed) internal view returns (uint256 answer) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x50d25bcd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			answer := mload(0x00)

			if slt(answer, 0x00) {
				answer := 0x00
			}
		}
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

	function setCurrencies() internal pure returns (Currency[] memory) {}

	function setCurrencies(Currency currency) internal pure returns (Currency[] memory assets) {
		assets = new Currency[](1);
		assets[0] = currency;
	}

	function setCurrencies(
		Currency currency0,
		Currency currency1
	) internal pure returns (Currency[] memory assets) {
		assets = new Currency[](2);
		assets[0] = currency0;
		assets[1] = currency1;
	}

	function setCurrencies(
		Currency currency0,
		Currency currency1,
		Currency currency2
	) internal pure returns (Currency[] memory assets) {
		assets = new Currency[](3);
		assets[0] = currency0;
		assets[1] = currency1;
		assets[2] = currency2;
	}

	function setCurrencies(
		Currency currency0,
		Currency currency1,
		Currency currency2,
		Currency currency3
	) internal pure returns (Currency[] memory assets) {
		assets = new Currency[](4);
		assets[0] = currency0;
		assets[1] = currency1;
		assets[2] = currency2;
		assets[3] = currency3;
	}

	function setCurrencies(
		Currency currency0,
		Currency currency1,
		Currency currency2,
		Currency currency3,
		Currency currency4
	) internal pure returns (Currency[] memory assets) {
		assets = new Currency[](5);
		assets[0] = currency0;
		assets[1] = currency1;
		assets[2] = currency2;
		assets[3] = currency3;
		assets[4] = currency4;
	}

	function setCurrencies(
		Currency currency0,
		Currency currency1,
		Currency currency2,
		Currency currency3,
		Currency currency4,
		Currency currency5
	) internal pure returns (Currency[] memory assets) {
		assets = new Currency[](6);
		assets[0] = currency0;
		assets[1] = currency1;
		assets[2] = currency2;
		assets[3] = currency3;
		assets[4] = currency4;
		assets[5] = currency5;
	}
}
