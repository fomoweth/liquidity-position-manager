// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface IStaker {
	struct PendingReward {
		Currency asset;
		uint256 amount;
	}

	function stake(bytes calldata params) external payable;

	function unstake(bytes calldata params) external payable;

	function getRewards(bytes calldata params) external payable;

	function getPendingRewards(bytes calldata params) external view returns (PendingReward[] memory);

	function getRewardsList(bytes calldata params) external view returns (Currency[] memory);
}
