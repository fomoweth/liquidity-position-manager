// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {V3_FACTORY} from "src/libraries/Constants.sol";
import {Currency} from "./Currency.sol";

using PoolKeyLibrary for PoolKey global;

struct PoolKey {
	Currency currency0;
	Currency currency1;
	uint24 fee;
}

function toPoolKey(Currency currencyA, Currency currencyB, uint24 fee) pure returns (PoolKey memory) {
	if (currencyA > currencyB) (currencyA, currencyB) = (currencyB, currencyA);
	return PoolKey({currency0: currencyA, currency1: currencyB, fee: fee});
}

/// @title PoolKeyLibrary
/// @notice Library for PoolKey struct

library PoolKeyLibrary {
	error InvalidPoolKey();

	bytes32 private constant V3_POOL_INIT_CODE_HASH =
		0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

	function compute(PoolKey memory key) internal view returns (address pool) {
		bytes32 salt = encode(key);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, add(hex"ff", shl(0x58, V3_FACTORY)))
			mstore(add(ptr, 0x15), salt)
			mstore(add(ptr, 0x35), V3_POOL_INIT_CODE_HASH)

			pool := and(
				keccak256(ptr, 0x55),
				0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
			)

			// reverts if pool hasn't deployed yet
			if iszero(extcodesize(pool)) {
				invalid()
			}
		}
	}

	function encode(PoolKey memory key) internal pure returns (bytes32 digest) {
		Currency currency0 = key.currency0;
		Currency currency1 = key.currency1;
		uint24 fee = key.fee;

		assembly ("memory-safe") {
			if gt(currency0, currency1) {
				let temp := currency0
				currency0 := currency1
				currency1 := temp
			}

			let ptr := mload(0x40)

			mstore(ptr, currency0)
			mstore(add(ptr, 0x20), currency1)
			mstore(add(ptr, 0x40), fee)

			digest := keccak256(ptr, 0x60)
		}
	}

	function tickSpacing(PoolKey memory key) internal pure returns (int24 ts) {
		uint24 fee = key.fee;

		assembly ("memory-safe") {
			switch eq(fee, 100)
			case 0x00 {
				ts := div(fee, 0x32)
			}
			default {
				ts := 0x01
			}
		}
	}

	function verify(PoolKey memory key) internal pure returns (PoolKey memory) {
		if (
			key.currency0.isZero() ||
			key.currency1.isZero() ||
			key.currency0 == key.currency1 ||
			key.currency0 > key.currency1 ||
			!checkFee(key.fee)
		) revert InvalidPoolKey();

		return key;
	}

	function checkFee(uint24 fee) private pure returns (bool res) {
		assembly ("memory-safe") {
			res := or(or(eq(fee, 100), eq(fee, 500)), or(eq(fee, 3000), eq(fee, 10000)))
		}
	}
}
