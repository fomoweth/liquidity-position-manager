// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {Currency} from "src/types/Currency.sol";
import {BaseModule} from "../../BaseModule.sol";

/// @title BaseLender

abstract contract BaseLender is BaseModule {
	error BadPrice();
	error NotCollateral();
	error NotBorrowable();

	address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address internal constant USD = 0x0000000000000000000000000000000000000348;

	address internal immutable denomination;

	Currency internal immutable WETH;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _denomination,
		Currency _wrappedNative,
		Currency _weth
	) BaseModule(_resolver, _protocol, _wrappedNative) {
		if (_denomination != ETH && _denomination != USD) {
			revert Errors.InvalidDenomination();
		}

		denomination = _denomination;
		WETH = _weth;
	}

	function getETHPrice() internal view virtual returns (uint256 price) {
		//
	}

	function isCollateral(address market, Currency asset) internal view virtual returns (bool);

	function isBorrowable(address market, Currency asset) internal view virtual returns (bool);
}
