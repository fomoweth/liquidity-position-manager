// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";
import {ILender} from "./ILender.sol";

interface ILendingDispatcher {
	function supply(bytes32 key, bytes calldata params) external payable;

	function borrow(bytes32 key, bytes calldata params) external payable;

	function repay(bytes32 key, bytes calldata params) external payable;

	function redeem(bytes32 key, bytes calldata params) external payable;

	function enterMarket(bytes32 key, bytes calldata params) external payable;

	function exitMarket(bytes32 key, bytes calldata params) external payable;

	function claimRewards(bytes32 key, bytes calldata params) external payable;

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
		);

	function getSupplyBalance(bytes32 key, bytes calldata params) external view returns (uint256);

	function getBorrowBalance(bytes32 key, bytes calldata params) external view returns (uint256);

	function getReserveData(
		bytes32 key,
		bytes calldata params
	) external view returns (ILender.ReserveData memory);

	function getReserveIndices(
		bytes32 key,
		bytes calldata params
	) external view returns (uint256 supplyIndex, uint256 borrowIndex, uint256 lastAccrualTime);

	function getLtv(bytes32 key, bytes calldata params) external view returns (uint256);

	function getAssetPrice(bytes32 key, bytes calldata params) external view returns (uint256);
}
