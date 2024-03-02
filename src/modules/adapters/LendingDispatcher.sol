// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILendingDispatcher} from "src/interfaces/ILendingDispatcher.sol";
import {ILender} from "src/interfaces/ILender.sol";
import {Currency} from "src/types/Currency.sol";
import {Dispatcher} from "src/base/Dispatcher.sol";
import {BaseModule} from "src/modules/BaseModule.sol";

/// @title LendingDispatcher
/// @notice Forwards calls made to this contract to lending adapter for the Client

contract LendingDispatcher is ILendingDispatcher, BaseModule, Dispatcher {
	constructor(
		address _resolver,
		bytes32 _key,
		Currency _wrappedNative
	) BaseModule(_resolver, _key, _wrappedNative) {}

	function supply(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), ILender.supply.selector, params);
	}

	function borrow(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), ILender.borrow.selector, params);
	}

	function repay(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), ILender.repay.selector, params);
	}

	function redeem(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), ILender.redeem.selector, params);
	}

	function enterMarket(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), ILender.enterMarket.selector, params);
	}

	function exitMarket(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), ILender.exitMarket.selector, params);
	}

	function claimRewards(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), ILender.claimRewards.selector, params);
	}

	function getAccountLiquidity(
		bytes32 key,
		bytes calldata params
	)
		external
		view
		returns (
			uint256 totalCollateral,
			uint256 totalLiability,
			uint256 availableLiquidity,
			uint256 healthFactor
		)
	{
		return
			abi.decode(
				callStatic(getAdapter(key), ILender.getAccountLiquidity.selector, params),
				(uint256, uint256, uint256, uint256)
			);
	}

	function getSupplyBalance(bytes32 key, bytes calldata params) external view returns (uint256) {
		return abi.decode(callStatic(getAdapter(key), ILender.getSupplyBalance.selector, params), (uint256));
	}

	function getBorrowBalance(bytes32 key, bytes calldata params) external view returns (uint256) {
		return abi.decode(callStatic(getAdapter(key), ILender.getBorrowBalance.selector, params), (uint256));
	}

	function getReserveData(
		bytes32 key,
		bytes calldata params
	) external view returns (ILender.ReserveData memory) {
		return
			abi.decode(
				callStatic(getAdapter(key), ILender.getReserveData.selector, params),
				(ILender.ReserveData)
			);
	}

	function getReserveIndices(
		bytes32 key,
		bytes calldata params
	) external view returns (uint256 supplyIndex, uint256 borrowIndex, uint256 lastAccrualTime) {
		return
			abi.decode(
				callStatic(getAdapter(key), ILender.getReserveIndices.selector, params),
				(uint256, uint256, uint256)
			);
	}

	function getLtv(bytes32 key, bytes calldata params) external view returns (uint256) {
		return abi.decode(callStatic(getAdapter(key), ILender.getLtv.selector, params), (uint256));
	}

	function getAssetPrice(bytes32 key, bytes calldata params) external view returns (uint256) {
		return abi.decode(callStatic(getAdapter(key), ILender.getAssetPrice.selector, params), (uint256));
	}

	function getAdapter(bytes32 key) internal view returns (address) {
		return resolver.getAddress(key);
	}
}
