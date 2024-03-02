// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency} from "src/types/Currency.sol";
import {BaseModule} from "src/modules/BaseModule.sol";

/// @title BaseLender
/// @notice Abstract base for lending adapters

abstract contract BaseLender is BaseModule {
	address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address internal constant USD = 0x0000000000000000000000000000000000000348;

	address internal immutable denomination;

	address internal immutable ETH_USD_FEED;

	Currency internal immutable WETH;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _denomination,
		address _ethUsdFeed,
		Currency _wrappedNative,
		Currency _weth
	) BaseModule(_resolver, _protocol, _wrappedNative) {
		if (_denomination != ETH && _denomination != USD) {
			revert Errors.InvalidDenomination();
		}

		denomination = _denomination;
		ETH_USD_FEED = _ethUsdFeed;
		WETH = _weth;
	}

	function getETHPrice() internal view virtual returns (uint256 answer) {
		address feed = ETH_USD_FEED;

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

	function decode(
		bytes calldata params
	) internal pure returns (Currency market, Currency asset, uint256 amount) {
		assembly ("memory-safe") {
			market := calldataload(params.offset)
			asset := calldataload(add(params.offset, 0x20))
			amount := calldataload(add(params.offset, 0x40))
		}
	}
}
