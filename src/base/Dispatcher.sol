// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Dispatcher
/// @dev Forwards calls made to this contract to given target

abstract contract Dispatcher {
	function dispatch(
		address target,
		bytes4 selector,
		bytes calldata params
	) internal virtual returns (bytes memory returndata) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, selector)
			calldatacopy(add(ptr, 0x04), params.offset, params.length)

			if iszero(delegatecall(gas(), target, ptr, add(params.length, 0x04), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}
	}

	function callStatic(
		address target,
		bytes4 selector,
		bytes calldata params
	) internal view virtual returns (bytes memory returndata) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, selector)
			calldatacopy(add(ptr, 0x04), params.offset, params.length)

			if iszero(staticcall(gas(), target, ptr, add(params.length, 0x04), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}
	}
}
