// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Singleton
/// @notice Assures whether this contract was called by delegatecall or not

abstract contract Singleton {
	error NoDelegateCall();
	error NotDelegateCall();

	address private immutable self;

	constructor() {
		self = address(this);
	}

	modifier checkDelegateCall() {
		_checkDelegateCall();
		_;
	}

	modifier noDelegateCall() {
		_noDelegateCall();
		_;
	}

	function _checkDelegateCall() internal view virtual {
		if (address(this) == self) revert NotDelegateCall();
	}

	function _noDelegateCall() internal view virtual {
		if (address(this) != self) revert NoDelegateCall();
	}
}
