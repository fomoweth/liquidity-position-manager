// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

/// @title Arrays
/// @notice modified from: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Arrays.sol

library Arrays {
	function at(address[] memory arr, uint256 pos) internal pure returns (address res) {
		assembly ("memory-safe") {
			res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
		}
	}

	function at(Currency[] memory arr, uint256 pos) internal pure returns (Currency res) {
		assembly ("memory-safe") {
			res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
		}
	}

	function at(bytes4[] memory arr, uint256 pos) internal pure returns (bytes4 res) {
		assembly ("memory-safe") {
			res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
		}
	}

	function at(bytes32[] memory arr, uint256 pos) internal pure returns (bytes32 res) {
		assembly ("memory-safe") {
			res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
		}
	}

	function at(uint256[] memory arr, uint256 pos) internal pure returns (uint256 res) {
		assembly ("memory-safe") {
			res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
		}
	}
}
