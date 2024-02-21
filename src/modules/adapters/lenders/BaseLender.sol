// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {Currency} from "src/types/Currency.sol";
import {BaseModule} from "../../BaseModule.sol";

/// @title BaseLender

abstract contract BaseLender is BaseModule {
	enum ReserveError {
		NoError,
		ZeroAddress,
		ZeroAmount,
		NotSupported,
		NotCollateral,
		NotBorrowable,
		NotActive,
		ExceededSupplyCap,
		ExceededBorrowCap
	}

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

	function verifyReserve(Currency market, Currency asset, uint256 amount, bool isCollateral) internal view {
		_validate(_verifyReserve(market, asset, amount, isCollateral));
	}

	function _verifyReserve(
		Currency market,
		Currency asset,
		uint256 amount,
		bool isCollateral
	) internal view virtual returns (ReserveError);

	function _isCollateral(Currency market, Currency asset) internal view virtual returns (bool);

	function _isBorrowable(Currency market, Currency asset) internal view virtual returns (bool);

	function _validate(ReserveError err) private pure {
		if (err == ReserveError.NoError) return;
		else if (err == ReserveError.ZeroAddress) revert Errors.ZeroAddress();
		else if (err == ReserveError.ZeroAmount) revert Errors.ZeroAmount();
		else if (err == ReserveError.NotSupported) revert Errors.NotSupported();
		else if (err == ReserveError.NotCollateral) revert Errors.NotCollateral();
		else if (err == ReserveError.NotBorrowable) revert Errors.NotBorrowable();
		else if (err == ReserveError.NotActive) revert Errors.NotActive();
		else if (err == ReserveError.ExceededSupplyCap) revert Errors.ExceededSupplyCap();
		else if (err == ReserveError.ExceededBorrowCap) revert Errors.ExceededBorrowCap();
	}
}
