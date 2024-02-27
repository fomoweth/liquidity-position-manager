// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CurveAdapter} from "src/modules/adapters/stakers/CurveAdapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockCurveAdapter is CurveAdapter {
	using CurrencyLibrary for Currency;

	constructor(
		address _resolver,
		bytes32 _protocol,
		Currency _wrappedNative,
		Currency _crv
	) CurveAdapter(_resolver, _protocol, _wrappedNative, _crv) {}

	function isAuthorized(address) internal view virtual override returns (bool) {
		return true;
	}

	function _checkDelegateCall() internal view virtual override {}

	function _noDelegateCall() internal view virtual override {}

	receive() external payable {}
}
