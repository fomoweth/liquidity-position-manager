// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ConvexCurveAdapter} from "src/modules/adapters/stakers/ConvexCurveAdapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockConvexCurveAdapter is ConvexCurveAdapter {
	using CurrencyLibrary for Currency;

	constructor(
		address _resolver,
		bytes32 _protocol,
		Currency _wrappedNative,
		Currency _crv,
		Currency _cvx
	) ConvexCurveAdapter(_resolver, _protocol, _wrappedNative, _crv, _cvx) {}

	function getPoolInfo(
		uint256 pid
	)
		public
		view
		returns (
			Currency rewardPool,
			Currency token,
			Currency lpToken,
			Currency gauge,
			address stash,
			bool shutdown
		)
	{
		return poolInfo(pid);
	}

	function userCheckpoint(Currency rewardPool) public {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4b82009300000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), rewardPool, 0x00, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}
}
