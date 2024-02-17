// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title FallbackHandler
/// @notice Handles fallback calls made to this contract

abstract contract FallbackHandler {
	error InvalidHandler();

	function delegate(address handler) internal virtual {
		if (handler == address(0)) revert InvalidHandler();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			calldatacopy(ptr, 0x00, calldatasize())

			let success := delegatecall(gas(), handler, ptr, calldatasize(), 0x00, 0x00)

			returndatacopy(ptr, 0x00, returndatasize())

			switch success
			case 0x00 {
				revert(ptr, returndatasize())
			}
			default {
				return(ptr, returndatasize())
			}
		}
	}

	function _fallback() internal virtual {
		delegate(fallbackHandler());
	}

	function _receive() internal virtual {
		assembly ("memory-safe") {
			if gt(calldatasize(), 0x00) {
				invalid()
			}
		}
	}

	function fallbackHandler() internal view virtual returns (address);

	fallback() external payable {
		_fallback();
	}

	receive() external payable {
		_receive();
	}
}
