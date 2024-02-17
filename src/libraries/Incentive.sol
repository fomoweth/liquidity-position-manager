// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

/// @title Incentive
/// @notice Computes the identifier for the staking incentive

library Incentive {
	struct Key {
		Currency rewardToken;
		address pool;
		uint40 startTime;
		uint40 endTime;
		address refundee;
	}

	function compute(Key memory key) internal pure returns (bytes32 digest) {
		Currency rewardToken = key.rewardToken;
		address pool = key.pool;
		uint256 startTime = key.startTime;
		uint256 endTime = key.endTime;
		address refundee = key.refundee;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, and(rewardToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x20), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x40), startTime)
			mstore(add(ptr, 0x60), endTime)
			mstore(add(ptr, 0x80), and(refundee, 0xffffffffffffffffffffffffffffffffffffffff))

			digest := keccak256(ptr, 0xa0)
		}
	}
}
