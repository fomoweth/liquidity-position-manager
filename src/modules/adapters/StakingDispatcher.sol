// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStakingDispatcher} from "src/interfaces/IStakingDispatcher.sol";
import {IStaker} from "src/interfaces/IStaker.sol";
import {Currency} from "src/types/Currency.sol";
import {Dispatcher} from "src/base/Dispatcher.sol";
import {BaseModule} from "src/modules/BaseModule.sol";

/// @title StakingDispatcher
/// @notice Forwards calls made to this contract to staking adapter for the Client

contract StakingDispatcher is IStakingDispatcher, BaseModule, Dispatcher {
	constructor(
		address _resolver,
		bytes32 _key,
		Currency _wrappedNative
	) BaseModule(_resolver, _key, _wrappedNative) {}

	function stake(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), IStaker.stake.selector, params);
	}

	function unstake(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), IStaker.unstake.selector, params);
	}

	function getRewards(bytes32 key, bytes calldata params) external payable {
		dispatch(getAdapter(key), IStaker.getRewards.selector, params);
	}

	function getPendingRewards(
		bytes32 key,
		bytes calldata params
	) external view returns (IStaker.PendingReward[] memory) {
		return
			abi.decode(
				callStatic(getAdapter(key), IStaker.getPendingRewards.selector, params),
				(IStaker.PendingReward[])
			);
	}

	function getRewardsList(bytes32 key, bytes calldata params) external view returns (Currency[] memory) {
		return abi.decode(callStatic(getAdapter(key), IStaker.getRewardsList.selector, params), (Currency[]));
	}

	function getAdapter(bytes32 key) internal view returns (address) {
		return resolver.getAddress(key);
	}
}
