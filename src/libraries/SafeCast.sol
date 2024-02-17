// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafeCast
/// @notice Contains methods for safely casting between types
/// @dev implementation from https://github.com/Uniswap/v4-core/blob/main/src/libraries/SafeCast.sol

library SafeCast {
	error SafeCastOverflow();

	function toUint40(uint256 value) internal pure returns (uint40 downcasted) {
		if (((downcasted = uint40(value)) != value)) revert SafeCastOverflow();
	}

	function toUint64(uint256 value) internal pure returns (uint64 downcasted) {
		if (((downcasted = uint64(value)) != value)) revert SafeCastOverflow();
	}

	function toUint96(uint256 value) internal pure returns (uint96 downcasted) {
		if (((downcasted = uint96(value)) != value)) revert SafeCastOverflow();
	}

	function toUint104(uint256 value) internal pure returns (uint104 downcasted) {
		if (((downcasted = uint104(value)) != value)) revert SafeCastOverflow();
	}

	function toUint112(uint256 value) internal pure returns (uint112 downcasted) {
		if (((downcasted = uint112(value)) != value)) revert SafeCastOverflow();
	}

	function toUint128(uint256 value) internal pure returns (uint128 downcasted) {
		if (((downcasted = uint128(value)) != value)) revert SafeCastOverflow();
	}

	function toUint160(uint256 value) internal pure returns (uint160 downcasted) {
		if (((downcasted = uint160(value)) != value)) revert SafeCastOverflow();
	}

	function toUint176(uint256 value) internal pure returns (uint176 downcasted) {
		if (((downcasted = uint176(value)) != value)) revert SafeCastOverflow();
	}

	function toUint256(int256 value) internal pure returns (uint256) {
		if (value < 0) revert SafeCastOverflow();
		return uint256(value);
	}

	function toInt88(int256 value) internal pure returns (int88 downcasted) {
		if (((downcasted = int88(value)) != value)) revert SafeCastOverflow();
	}

	function toInt88(uint256 value) internal pure returns (int88 downcasted) {
		if (value > uint88(type(int88).max)) revert SafeCastOverflow();
		downcasted = int88(int256(value));
	}

	function toInt104(int256 value) internal pure returns (int104 downcasted) {
		if (((downcasted = int104(value)) != value)) revert SafeCastOverflow();
	}

	function toInt104(uint256 value) internal pure returns (int104 downcasted) {
		if (value > uint104(type(int104).max)) revert SafeCastOverflow();
		downcasted = int104(int256(value));
	}

	function toInt128(int256 value) internal pure returns (int128 downcasted) {
		if (((downcasted = int128(value)) != value)) revert SafeCastOverflow();
	}

	function toInt128(uint256 value) internal pure returns (int128 downcasted) {
		if (value > uint128(type(int128).max)) revert SafeCastOverflow();
		downcasted = int128(int256(value));
	}

	function toInt256(uint256 value) internal pure returns (int256) {
		if (value > uint256(type(int256).max)) revert SafeCastOverflow();
		return int256(value);
	}
}
