// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILender} from "src/interfaces/ILender.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseLender} from "./BaseLender.sol";

/// @title CompoundV3Adapter
/// @notice Provides the functionality of making calls to Compound-V3 contracts for the Client

contract CompoundV3Adapter is ILender, BaseLender {
	using CurrencyLibrary for Currency;
	using FullMath for uint256;
	using PercentageMath for uint256;
	using SafeCast for uint256;
	using WadRayMath for uint256;

	bytes4 internal constant COMET_SUPPLY_SELECTOR = 0xf2b9fdb8;
	bytes4 internal constant COMET_WITHDRAW_SELECTOR = 0xf3fef3a3;

	address internal immutable CONFIGURATOR;
	address internal immutable REWARDS;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _configurator,
		address _rewards,
		address _denomination,
		Currency _wrappedNative,
		Currency _weth
	) BaseLender(_resolver, _protocol, _denomination, _wrappedNative, _weth) {
		CONFIGURATOR = _configurator;
		REWARDS = _rewards;
	}

	function supply(
		bytes calldata params
	) public payable returns (uint128 reserveIndex, uint40 lastAccruedTimestamp) {
		//
	}

	function borrow(
		bytes calldata params
	) public payable returns (uint128 reserveIndex, uint40 lastAccruedTimestamp) {
		//
	}

	function repay(
		bytes calldata params
	) public payable returns (uint128 reserveIndex, uint40 lastAccruedTimestamp) {
		//
	}

	function redeem(
		bytes calldata params
	) public payable returns (uint128 reserveIndex, uint40 lastAccruedTimestamp) {
		//
	}

	function enableMarket(bytes calldata params) public payable {
		//
	}

	function enterMarket(bytes calldata) public payable {
		revert Errors.NotSupported();
	}

	function exitMarket(bytes calldata) public payable {
		revert Errors.NotSupported();
	}

	function claimRewards(bytes calldata params) public payable {
		//
	}

	function getReserveData(bytes calldata params) external view returns (ReserveData memory reserveData) {
		//
	}

	function _verifyReserve(
		Currency comet,
		Currency asset,
		uint256 amount,
		bool useAsCollateral
	) internal view virtual override returns (ReserveError) {
		//
	}

	function decode(
		bytes calldata params
	) internal pure returns (Currency comet, Currency asset, uint256 amount) {
		assembly ("memory-safe") {
			comet := calldataload(params.offset)
			asset := calldataload(add(params.offset, 0x20))
			amount := calldataload(add(params.offset, 0x40))
		}
	}
}
