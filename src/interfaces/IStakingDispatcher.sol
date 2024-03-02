// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";
import {IStaker} from "./IStaker.sol";

interface IStakingDispatcher {
	function stake(bytes32 key, bytes calldata params) external payable;

	function unstake(bytes32 key, bytes calldata params) external payable;

	function getRewards(bytes32 key, bytes calldata params) external payable;

	function getPendingRewards(
		bytes32 key,
		bytes calldata params
	) external view returns (IStaker.PendingReward[] memory);

	function getRewardsList(bytes32 key, bytes calldata params) external view returns (Currency[] memory);
}
