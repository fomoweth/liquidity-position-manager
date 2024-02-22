// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BytesLib
/// @dev implementation from: https://github.com/Uniswap/universal-router/blob/main/contracts/modules/uniswap/v3/BytesLib.sol

library BytesLib {
	error SliceOutOfBounds();

	function toAddress(bytes calldata data) internal pure returns (address res) {
		if (data.length < 20) revert SliceOutOfBounds();

		assembly ("memory-safe") {
			res := calldataload(data.offset)
		}
	}

	function toBytes(bytes calldata data, uint256 index) internal pure returns (bytes calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toAddressArray(
		bytes calldata data,
		uint256 index
	) internal pure returns (address[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toBytesArray(bytes calldata data, uint256 index) internal pure returns (bytes[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toBytes4Array(bytes calldata data, uint256 index) internal pure returns (bytes4[] calldata res) {
		(uint256 length, uint256 offset) = toLengthOffset(data, index);

		assembly ("memory-safe") {
			res.length := length
			res.offset := offset
		}
	}

	function toLengthOffset(
		bytes calldata data,
		uint256 index
	) internal pure returns (uint256 length, uint256 offset) {
		bool success;

		assembly ("memory-safe") {
			// The offset of the `_arg`-th element is `32 * arg`, which stores the offset of the length pointer.
			// shl(5, x) is equivalent to mul(32, x)
			let lengthPtr := add(data.offset, calldataload(add(data.offset, shl(0x05, index))))
			length := calldataload(lengthPtr)
			offset := add(lengthPtr, 0x20)

			success := iszero(lt(data.length, add(length, sub(offset, data.offset))))
		}

		if (!success) revert SliceOutOfBounds();
	}
}
