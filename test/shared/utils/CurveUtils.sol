// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Common} from "./Common.sol";

abstract contract CurveUtils is Common {
	using CurrencyLibrary for Currency;

	function calcTokenAmount(
		address pool,
		uint256 offset,
		uint256 length,
		uint256 amount,
		bool isDeposit
	) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch length
			case 0x02 {
				mstore(ptr, 0xed8e84f300000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), 0x00)
				mstore(add(ptr, 0x24), 0x00)
				mstore(add(ptr, 0x44), and(isDeposit, 0xff))
			}
			case 0x03 {
				mstore(ptr, 0x3883e11900000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), 0x00)
				mstore(add(ptr, 0x24), 0x00)
				mstore(add(ptr, 0x44), 0x00)
				mstore(add(ptr, 0x64), and(isDeposit, 0xff))
			}
			case 0x04 {
				mstore(ptr, 0xcf701ff700000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), 0x00)
				mstore(add(ptr, 0x24), 0x00)
				mstore(add(ptr, 0x44), 0x00)
				mstore(add(ptr, 0x64), 0x00)
				mstore(add(ptr, 0x84), and(isDeposit, 0xff))
			}
			case 0x05 {
				mstore(ptr, 0x7ede89c500000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), 0x00)
				mstore(add(ptr, 0x24), 0x00)
				mstore(add(ptr, 0x44), 0x00)
				mstore(add(ptr, 0x64), 0x00)
				mstore(add(ptr, 0x84), 0x00)
				mstore(add(ptr, 0xa4), and(isDeposit, 0xff))
			}
			case 0x06 {
				mstore(ptr, 0x40f2e5bd00000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), 0x00)
				mstore(add(ptr, 0x24), 0x00)
				mstore(add(ptr, 0x44), 0x00)
				mstore(add(ptr, 0x64), 0x00)
				mstore(add(ptr, 0x84), 0x00)
				mstore(add(ptr, 0xa4), 0x00)
				mstore(add(ptr, 0xc4), and(isDeposit, 0xff))
			}
			default {
				invalid()
			}

			mstore(add(ptr, add(mul(offset, 0x20), 0x04)), amount)

			if iszero(staticcall(gas(), pool, ptr, add(mul(length, 0x20), 0x24), 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function calcWithdrawOneCoin(
		address pool,
		uint256 liquidity,
		uint256 offset
	) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb137392900000000000000000000000000000000000000000000000000000000)

			switch staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)
			case 0x00 {
				mstore(ptr, 0xcc2b27d700000000000000000000000000000000000000000000000000000000)
			}
			default {
				mstore(ptr, 0x4fb08c5e00000000000000000000000000000000000000000000000000000000)
			}

			mstore(add(ptr, 0x04), liquidity)
			mstore(add(ptr, 0x24), offset)

			if iszero(staticcall(gas(), pool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function getVirtualPrice(address pool) internal view returns (uint256 price) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xbb7b8b8000000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			price := mload(0x00)
		}
	}

	function poolVersion(address pool) internal view returns (uint8 version) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb137392900000000000000000000000000000000000000000000000000000000)

			switch staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)
			case 0x00 {
				version := 0x01
			}
			default {
				version := 0x02
			}
		}
	}

	function poolAssets(
		address pool,
		uint256 offset,
		bool isUnderlying
	) internal view returns (Currency asset) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isUnderlying
			case 0x00 {
				mstore(ptr, 0xc661065700000000000000000000000000000000000000000000000000000000)
			}
			default {
				mstore(ptr, 0xb9947eb000000000000000000000000000000000000000000000000000000000)
			}

			mstore(add(ptr, 0x04), offset)

			if iszero(staticcall(gas(), pool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			asset := mload(0x00)
		}
	}
}
