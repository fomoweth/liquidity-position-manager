// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {ClientStorage} from "src/libraries/ClientStorage.sol";
import {Currency} from "src/types/Currency.sol";
import {Authority} from "src/base/Authority.sol";
import {Chain} from "src/base/Chain.sol";
import {Payments} from "src/base/Payments.sol";
import {Singleton} from "src/base/Singleton.sol";

/// @title BaseModule

abstract contract BaseModule is Authority, Chain, Singleton, Payments {
	bytes32 public immutable key;

	IAddressResolver internal immutable resolver;

	uint256 internal constant MAX_UINT256 = 2 ** 256 - 1;

	constructor(address _resolver, bytes32 _key, Currency _wrappedNative) Payments(_wrappedNative) {
		key = _key;
		resolver = IAddressResolver(_resolver);
	}

	function isAuthorized(address account) internal view virtual override returns (bool) {
		return ClientStorage.load().owner == account;
	}
}
