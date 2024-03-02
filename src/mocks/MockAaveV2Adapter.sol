// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AaveV2Adapter} from "src/modules/adapters/lenders/AaveV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockAaveV2Adapter is AaveV2Adapter {
	using CurrencyLibrary for Currency;

	bytes constant ZERO_BYTES = new bytes(0);

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _lendingPool,
		address _incentives,
		address _priceOracle,
		address _denomination,
		address _ethUsdFeed,
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
			_ethUsdFeed,
			_wrappedNative,
			_weth
		)
	{}

	function claimRewards() public payable {
		this.claimRewards(ZERO_BYTES);
	}

	function getPendingRewards() public view returns (uint256) {
		return this.getPendingRewards(ZERO_BYTES);
	}

	function getMarketsIn() public view returns (Currency[] memory) {
		return getMarketsIn(LENDING_POOL, address(this));
	}

	function getReservesList() public view returns (Currency[] memory) {
		return getReservesList(LENDING_POOL);
	}

	function getRewardAsset() public view returns (Currency) {
		return getRewardAsset(INCENTIVES);
	}

	function underlyingToAToken(Currency underlying) public view returns (Currency aToken) {
		(, , , , , , , aToken, , , , ) = getReserveData(LENDING_POOL, underlying);
	}

	function underlyingToVDebtToken(Currency underlying) public view returns (Currency vdToken) {
		(, , , , , , , , , vdToken, , ) = getReserveData(LENDING_POOL, underlying);
	}

	function marketToUnderlying(Currency market) public view returns (Currency underlying) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb16a19de00000000000000000000000000000000000000000000000000000000) // UNDERLYING_ASSET_ADDRESS()

			if iszero(staticcall(gas(), market, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			underlying := mload(0x00)
		}
	}

	function getLtv(Currency asset) public view returns (uint256) {
		return getValue(getConfiguration(LENDING_POOL, asset), LTV_MASK, 0);
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
		return getUserConfiguration(LENDING_POOL, address(this));
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
		return getUserAccountData(LENDING_POOL, address(this));
	}

	function getPrice(Currency asset) public view returns (uint256) {
		return getAssetPrice(asset);
	}

	function getPriceFeed(Currency asset) public view returns (address) {
		return getPriceFeed(PRICE_ORACLE, asset);
	}

	function isAssetIn(Currency asset) public view returns (bool) {
		(, , , , , , , , , , , uint8 id) = getReserveData(LENDING_POOL, asset);
		return isAssetIn(getUserConfiguration(LENDING_POOL, address(this)), id);
	}

	function isSupplying(Currency asset) public view returns (bool) {
		(, , , , , , , , , , , uint8 id) = getReserveData(LENDING_POOL, asset);
		return isSupplying(getUserConfiguration(LENDING_POOL, address(this)), id);
	}

	function isBorrowing(Currency asset) public view returns (bool) {
		(, , , , , , , , , , , uint8 id) = getReserveData(LENDING_POOL, asset);
		return isBorrowing(getUserConfiguration(LENDING_POOL, address(this)), id);
	}

	function isAuthorized(address) internal view virtual override returns (bool) {
		return true;
	}

	function _checkDelegateCall() internal view virtual override {}

	function _noDelegateCall() internal view virtual override {}

	receive() external payable {}
}
