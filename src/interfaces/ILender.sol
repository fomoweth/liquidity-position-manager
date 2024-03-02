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
		bool canSupply;
		bool canBorrow;
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

	function getAccountLiquidity(
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

	function getSupplyBalance(bytes calldata params) external view returns (uint256 supplyBalance);

	function getBorrowBalance(bytes calldata params) external view returns (uint256 borrowBalance);

	function getReserveData(bytes calldata params) external view returns (ReserveData memory reserveData);

	function getReserveIndices(
		bytes calldata params
	) external view returns (uint256 supplyIndex, uint256 borrowIndex, uint256 lastAccrualTime);

	function getLtv(bytes calldata params) external view returns (uint256);

	function getAssetPrice(bytes calldata params) external view returns (uint256);
}
