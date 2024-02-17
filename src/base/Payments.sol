// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

/// @title Payments
/// @notice Handles various operations around the payment of native token and tokens

abstract contract Payments {
	using CurrencyLibrary for Currency;

	Currency internal immutable WRAPPED_NATIVE;

	constructor(Currency _wrappedNative) {
		WRAPPED_NATIVE = _wrappedNative;
	}

	function approveIfNeeded(Currency currency, address spender, uint256 amount) internal {
		if (currency.allowance(address(this), spender) < amount) {
			currency.approve(spender, amount);
		}
	}

	function pay(Currency currency, address payer, address recipient, uint256 amount) internal {
		if (amount != 0) {
			if (payer == address(this)) currency.transfer(recipient, amount);
			else currency.transferFrom(payer, recipient, amount);
		}
	}

	function wrapETH(uint256 amount) internal {
		Currency wrappedNative = WRAPPED_NATIVE;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000) // deposit()

			if iszero(call(gas(), wrappedNative, amount, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unwrapWETH(uint256 amount) internal {
		Currency wrappedNative = WRAPPED_NATIVE;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000) // withdraw(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), wrappedNative, 0x00, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}
}
