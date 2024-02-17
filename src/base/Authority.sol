// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/utils/Context.sol";

/// @title Authority
/// @notice Authorizes msg.sender of calls made to this contract

abstract contract Authority is Context {
	error AccessDenied();

	modifier authorized() {
		checkAccess();
		_;
	}

	function checkAccess() internal view {
		if (!isAuthorized(_msgSender())) revert AccessDenied();
	}

	function isAuthorized(address account) internal view virtual returns (bool);
}
