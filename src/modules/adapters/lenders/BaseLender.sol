// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency} from "src/types/Currency.sol";
import {BaseModule} from "../../BaseModule.sol";

/// @title BaseLender

abstract contract BaseLender is BaseModule {
	enum ReserveError {
		NoError,
		ZeroAddress,
		ZeroAmount,
		NotSupported,
		NotCollateral,
		NotBorrowable,
		NotActive
	}

	address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address internal constant USD = 0x0000000000000000000000000000000000000348;

	address internal immutable denomination;

	Currency internal immutable WETH;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _denomination,
		Currency _wrappedNative,
		Currency _weth
	) BaseModule(_resolver, _protocol, _wrappedNative) {
		if (_denomination != ETH && _denomination != USD) {
			revert Errors.InvalidDenomination();
		}

		denomination = _denomination;
		WETH = _weth;
	}

	function getETHPrice() internal view virtual returns (uint256 price) {
		//
	}

	function derivePrice(
		uint256 baseAnswer,
		uint256 quoteAnswer,
		uint8 baseDecimals,
		uint8 quoteDecimals,
		uint8 assetDecimals
	) internal pure returns (uint256) {
		unchecked {
			if (baseAnswer == 0 || quoteAnswer == 0) return 0;

			return
				FullMath.mulDiv(
					scalePrice(baseAnswer, baseDecimals, assetDecimals),
					10 ** assetDecimals,
					scalePrice(quoteAnswer, quoteDecimals, assetDecimals)
				);
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

	function verifyReserve(
		Currency market,
		Currency asset,
		uint256 amount,
		bool useAsCollateral
	) internal view {
		_validate(_verifyReserve(market, asset, amount, useAsCollateral));
	}

	function _verifyReserve(
		Currency market,
		Currency asset,
		uint256 amount,
		bool useAsCollateral
	) internal view virtual returns (ReserveError);

	function _validate(ReserveError err) private pure {
		if (err == ReserveError.NoError) return;
		else if (err == ReserveError.ZeroAddress) revert Errors.ZeroAddress();
		else if (err == ReserveError.ZeroAmount) revert Errors.ZeroAmount();
		else if (err == ReserveError.NotSupported) revert Errors.NotSupported();
		else if (err == ReserveError.NotCollateral) revert Errors.NotCollateral();
		else if (err == ReserveError.NotBorrowable) revert Errors.NotBorrowable();
		else if (err == ReserveError.NotActive) revert Errors.NotActive();
	}
}
