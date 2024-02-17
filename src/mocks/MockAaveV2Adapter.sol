// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AaveV2Adapter} from "src/modules/adapters/lenders/AaveV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockAaveV2Adapter is AaveV2Adapter {
	using CurrencyLibrary for Currency;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _lendingPool,
		address _incentives,
		address _priceOracle,
		address _denomination,
		Currency _wrappedNative,
		Currency _weth
	)
		AaveV2Adapter(
			_resolver,
			_protocol,
			_lendingPool,
			_incentives,
			_priceOracle,
			_denomination,
			_wrappedNative,
			_weth
		)
	{}

	function supply(
		Currency market,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (uint128 liquidityIndex, uint40 lastUpdateTimestamp, uint256 balancePrior, uint256 balanceNew)
	{
		balancePrior = market.balanceOfSelf();

		(liquidityIndex, lastUpdateTimestamp) = this.supply(abi.encode(asset, amount));

		balanceNew = market.balanceOfSelf();
	}

	function borrow(
		Currency market,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (
			uint128 variableBorrowIndex,
			uint40 lastUpdateTimestamp,
			uint256 balancePrior,
			uint256 balanceNew
		)
	{
		balancePrior = market.balanceOfSelf();

		(variableBorrowIndex, lastUpdateTimestamp) = this.borrow(abi.encode(asset, amount));

		balanceNew = market.balanceOfSelf();
	}

	function repay(
		Currency market,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (
			uint128 variableBorrowIndex,
			uint40 lastUpdateTimestamp,
			uint256 balancePrior,
			uint256 balanceNew
		)
	{
		balancePrior = market.balanceOfSelf();

		(variableBorrowIndex, lastUpdateTimestamp) = this.repay(abi.encode(asset, amount));

		balanceNew = market.balanceOfSelf();
	}

	function redeem(
		Currency market,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (uint128 liquidityIndex, uint40 lastUpdateTimestamp, uint256 balancePrior, uint256 balanceNew)
	{
		balancePrior = market.balanceOfSelf();

		(liquidityIndex, lastUpdateTimestamp) = this.redeem(abi.encode(asset, amount));

		balanceNew = market.balanceOfSelf();
	}

	function enableMarket(Currency asset, bool enable) public payable {
		this.enableMarket(abi.encode(asset, enable));
	}

	function claimRewards() public payable {
		this.claimRewards("0x");
	}

	function isCollateral(Currency asset) public view returns (bool) {
		return isCollateral(address(0), asset);
	}

	function isBorrowable(Currency asset) public view returns (bool) {
		return isBorrowable(address(0), asset);
	}

	function getAssetPrice(Currency asset) public view returns (uint256) {
		return getAssetPrice(PRICE_ORACLE, asset);
	}

	function getPriceFeed(Currency asset) public view returns (address) {
		return getPriceFeed(PRICE_ORACLE, asset);
	}

	function getReserveData(
		Currency asset
	)
		public
		view
		returns (
			uint256 configuration,
			uint128 liquidityIndex,
			uint128 variableBorrowIndex,
			uint128 currentLiquidityRate,
			uint128 currentVariableBorrowRate,
			uint128 currentStableBorrowRate,
			uint40 lastUpdateTimestamp,
			Currency aToken,
			Currency stableDebtToken,
			Currency variableDebtToken,
			address interestRateStrategy,
			uint8 id
		)
	{
		return getReserveData(LENDING_POOL, asset);
	}

	function getConfiguration(Currency asset) public view returns (uint256) {
		return getConfiguration(LENDING_POOL, asset);
	}

	function getUserConfiguration() public view returns (uint256) {
		return getUserConfiguration(LENDING_POOL);
	}

	function getUserAccountData()
		public
		view
		returns (
			uint256 totalCollateral,
			uint256 totalDebt,
			uint256 availableBorrows,
			uint256 currentLiquidationThreshold,
			uint256 ltv,
			uint256 healthFactor
		)
	{
		return getUserAccountData(LENDING_POOL);
	}

	function isAssetIn(Currency asset) public view returns (bool) {
		(, , , , , , , , , , , uint8 id) = getReserveData(LENDING_POOL, asset);
		return isAssetIn(getUserConfiguration(LENDING_POOL), id);
	}

	function isSupplying(Currency asset) public view returns (bool) {
		(, , , , , , , , , , , uint8 id) = getReserveData(LENDING_POOL, asset);
		return isSupplying(getUserConfiguration(LENDING_POOL), id);
	}

	function isBorrowing(Currency asset) public view returns (bool) {
		(, , , , , , , , , , , uint8 id) = getReserveData(LENDING_POOL, asset);
		return isBorrowing(getUserConfiguration(LENDING_POOL), id);
	}

	function isAuthorized(address) internal view virtual override returns (bool) {
		return true;
	}

	receive() external payable {}
}
