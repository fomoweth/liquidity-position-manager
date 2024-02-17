// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Errors
/// @notice Custom errors library

library Errors {
	error ZeroAddress();

	error ZeroBytes();

	error ZeroValue();

	error EmptyArray();

	error ConfiguredAlready();

	error ExistsAlready();

	error NotExists();

	error NotActive();

	error NotSupported();

	error InvalidAsset();

	error InvalidCaller();

	error InvalidCallValue();

	error InvalidDenomination();

	error InvalidModule();

	error InvalidPool();

	error InvalidSwap();

	error InsufficientBalance();

	error InsufficientLiquidity();

	error Slippage();

	error ExceededMaxLimit();
}
