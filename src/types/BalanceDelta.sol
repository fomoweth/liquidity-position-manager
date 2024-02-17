// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

type BalanceDelta is int256;

using {add as +, sub as -, eq as ==} for BalanceDelta global;
using BalanceDeltaLibrary for BalanceDelta global;

function toBalanceDelta(int128 amount0, int128 amount1) pure returns (BalanceDelta balanceDelta) {
	assembly ("memory-safe") {
		balanceDelta := or(
			shl(0x80, amount0),
			and(0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, amount1)
		)
	}
}

function add(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
	return toBalanceDelta(a.amount0() + b.amount0(), a.amount1() + b.amount1());
}

function sub(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
	return toBalanceDelta(a.amount0() - b.amount0(), a.amount1() - b.amount1());
}

function eq(BalanceDelta a, BalanceDelta b) pure returns (bool) {
	return a.amount0() == b.amount0() && a.amount1() == b.amount1();
}

/// @title BalanceDeltaLibrary
/// @dev implementation from: https://github.com/Uniswap/v4-core/blob/main/src/types/BalanceDelta.sol

library BalanceDeltaLibrary {
	BalanceDelta internal constant MAXIMUM_DELTA = BalanceDelta.wrap(int256(type(uint256).max));

	function amount0(BalanceDelta balanceDelta) internal pure returns (int128 amount) {
		assembly ("memory-safe") {
			amount := shr(0x80, balanceDelta)
		}
	}

	function amount1(BalanceDelta balanceDelta) internal pure returns (int128 amount) {
		assembly ("memory-safe") {
			amount := balanceDelta
		}
	}
}
