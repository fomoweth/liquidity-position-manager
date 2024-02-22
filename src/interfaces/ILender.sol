// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface ILender {
	struct ReserveData {
		Currency collateralMarket;
		Currency borrowMarket;
		address priceFeed;
		uint256 price;
		uint256 ltv;
		uint256 supplyRate;
		uint256 borrowRate;
		uint256 supplyIndex;
		uint256 borrowIndex;
		uint40 lastAccrualTime;
		bool isCollateral;
		bool isBorrowable;
		bool isActive;
	}

	function supply(
		bytes calldata params
	) external payable returns (uint128 reserveIndex, uint40 lastAccrualTime);

	function borrow(
		bytes calldata params
	) external payable returns (uint128 reserveIndex, uint40 lastAccrualTime);

	function repay(
		bytes calldata params
	) external payable returns (uint128 reserveIndex, uint40 lastAccrualTime);

	function redeem(
		bytes calldata params
	) external payable returns (uint128 reserveIndex, uint40 lastAccrualTime);

	function enterMarket(bytes calldata params) external payable;

	function exitMarket(bytes calldata params) external payable;

	function claimRewards(bytes calldata params) external payable;

	function getReserveData(bytes calldata params) external view returns (ReserveData memory reserveData);
}
