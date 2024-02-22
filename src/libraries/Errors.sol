// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Errors
/// @notice Custom errors library

library Errors {
	error ZeroAddress();

	error ZeroAmount();

	error ZeroBytes();

	error ZeroValue();

	error EmptyArray();

	error ConfiguredAlready();

	error ExistsAlready();

	error NotExists();

	error NotActive();

	error NotSupported();

	error NotCollateral();

	error NotBorrowable();

	error InvalidCaller();

	error InvalidCallValue();

	error InvalidCommand(uint8 command);

	error InvalidDenomination();

	error InvalidModule();

	error InvalidPool();

	error InvalidSignature();

	error InvalidSwap();

	error InsufficientBalance();

	error InsufficientLiquidity();

	error Slippage();

	error ExceededMaxLimit();

	error BadPrice();
}
