// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {ILender} from "src/interfaces/ILender.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {CurrencyState} from "test/shared/states/CurrencyState.sol";
import {CompoundV2Config, CompoundMarket} from "test/shared/states/DataTypes.sol";
import {Utils} from "./Utils.sol";

abstract contract CompoundUtils is CommonBase, CurrencyState, Utils {
	using CurrencyLibrary for Currency;
	using WadRayMath for uint256;

	CompoundV2Config compV2Config;

	function setUpCompound(uint256 chainId) internal virtual {
		if (chainId == ETHEREUM_CHAIN_ID) {
			compV2Config = CompoundV2Config({
				protocol: COMP_V2_ID,
				comptroller: 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B,
				oracle: 0x50ce56A3239671Ab62f185704Caedf626352741e,
				cNative: toCurrency(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5),
				cETH: toCurrency(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5),
				denomination: USD
			});
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			compV2Config = CompoundV2Config({
				protocol: toBytes32("SONNE"),
				comptroller: 0x60CF091cD3f50420d50fD7f707414d0DF4751C58,
				oracle: 0x91579f47f7826471C08B0008eE9C778aaB2989fD,
				cNative: ZERO,
				cETH: toCurrency(0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E),
				denomination: USD
			});
		} else if (chainId == POLYGON_CHAIN_ID) {
			compV2Config = CompoundV2Config({
				protocol: toBytes32("KEOM"),
				comptroller: 0x5B7136CFFd40Eee5B882678a5D02AA25A48d669F,
				oracle: 0x828fb251167145F89cd479f9D71a5A762F23BF13,
				cNative: toCurrency(0x7854D4Cfa7d0B877E399bcbDFfb49536d7A14fc7),
				cETH: toCurrency(0x44010CBf1EC8B8D8275d86D8e28278C06DD07C48),
				denomination: USD
			});
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			compV2Config = CompoundV2Config({
				protocol: toBytes32("LODE"),
				comptroller: 0xa86DD95c210dd186Fa7639F93E4177E97d057576,
				oracle: 0xcCf9393df2F656262FD79599175950faB4D4ec01,
				cNative: toCurrency(0x2193c45244AF12C280941281c8aa67dD08be0a64),
				cETH: toCurrency(0x2193c45244AF12C280941281c8aa67dD08be0a64),
				denomination: USD
			});
		}

		if (compV2Config.protocol != bytes32(0)) {
			vm.label(compV2Config.comptroller, "Comptroller");
			vm.label(compV2Config.oracle, "CompoundV2Oracle");
			// vm.label(compV2Config.cNative.toAddress(), "cNATIVE");
			// vm.label(compV2Config.cETH.toAddress(), "cETH");
		}
	}

	function getCTokenMarkets(
		Currency[] memory assets
	) internal returns (CompoundMarket[] memory cTokenMarkets) {
		Currency[] memory cTokens = getAllMarkets(true);

		cTokenMarkets = new CompoundMarket[](assets.length);

		for (uint256 i; i < assets.length; ++i) {
			Currency asset = assets[i];

			for (uint256 j; j < cTokens.length; ++j) {
				Currency cToken = cTokens[j];
				Currency underlying = cTokenToUnderlying(cToken);

				if (asset == underlying) {
					uint256 lastIndex = cTokens.length - 1;
					if (lastIndex != j) cTokens[j] = cTokens[lastIndex];

					assembly ("memory-safe") {
						mstore(cTokens, lastIndex)
					}

					cTokenMarkets[i] = CompoundMarket(cToken, asset, getLtv(cToken));

					vm.label(asset.toAddress(), symbol(asset));
					vm.label(cToken.toAddress(), symbol(cToken));
				}
			}
		}
	}

	function getAllMarkets(bool filterDeprecated) internal view returns (Currency[] memory cTokens) {
		address comptroller = compV2Config.comptroller;

		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb0772d0b00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comptroller, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		Currency[] memory allCTokens = abi.decode(returndata, (Currency[]));

		if (!filterDeprecated) return allCTokens;

		cTokens = new Currency[](allCTokens.length);
		uint256 count;

		for (uint256 i; i < allCTokens.length; ++i) {
			if (!isDeprecated(allCTokens[i])) {
				cTokens[count] = allCTokens[i];
				++count;
			}
		}

		assembly ("memory-safe") {
			mstore(cTokens, count)
		}
	}

	function cTokenToUnderlying(Currency cToken) internal view returns (Currency underlying) {
		if (cToken == compV2Config.cNative) return WRAPPED_NATIVE;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6f307dc300000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			underlying := mload(0x00)
		}
	}

	function getCompoundPrice(Currency cToken, uint256 unit) internal view returns (uint256) {
		if (cToken == compV2Config.cETH) return WAD;

		uint256 ethPrice = getUnderlyingPrice(compV2Config.oracle, compV2Config.cETH, 18);
		uint256 price = getUnderlyingPrice(compV2Config.oracle, cToken, unit);

		return derivePrice(price, ethPrice, 8, 8, 18);
	}

	function getUnderlyingPrice(
		address oracle,
		Currency cToken,
		uint256 unit
	) private view returns (uint256 price) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xfc57d4df00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), oracle, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			price := div(mload(0x00), exp(10, sub(28, unit)))
		}
	}

	function getLtv(Currency cToken) internal view returns (uint16 ltv) {
		address comptroller = compV2Config.comptroller;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x8e8f294b00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, add(ptr, 0x24), 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			ltv := div(mload(add(ptr, 0x44)), exp(10, 14))
		}
	}

	function isDeprecated(Currency cToken) internal view returns (bool deprecated) {
		address comptroller = compV2Config.comptroller;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x94543c1500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			deprecated := mload(0x00)
		}
	}

	function getAccountLiquidity(
		address account
	) internal view returns (uint256 liquidity, uint256 shortfall) {
		address comptroller = compV2Config.comptroller;

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x5ec88c7900000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			liquidity := mload(add(res, 0x20))
			shortfall := mload(add(res, 0x40))
		}
	}

	function getAccountSnapshot(
		Currency cToken,
		address account
	) internal view returns (uint256 cTokenBalance, uint256 borrowBalance, uint256 exchangeRate) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0xc37f68e200000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), cToken, ptr, 0x24, res, 0x80)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			cTokenBalance := mload(add(res, 0x20))
			borrowBalance := mload(add(res, 0x40))
			exchangeRate := mload(add(res, 0x60))
		}
	}
}
