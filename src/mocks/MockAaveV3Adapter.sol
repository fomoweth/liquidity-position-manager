// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AaveV3Adapter} from "src/modules/adapters/lenders/AaveV3Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockAaveV3Adapter is AaveV3Adapter {
	using CurrencyLibrary for Currency;

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
		AaveV3Adapter(
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
		this.claimRewards("0x");
	}

	function getPendingRewards(Currency rewardAsset) public view returns (uint256) {
		return getPendingRewards(INCENTIVES, rewardAsset);
	}

	function getMarketsIn() public view returns (Currency[] memory) {
		return getMarketsIn(LENDING_POOL, INCENTIVES, false);
	}

	function getReservesList() public view returns (Currency[] memory) {
		return getReservesList(LENDING_POOL);
	}

	function getRewardsList() public view returns (Currency[] memory) {
		address incentives = INCENTIVES;

		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb45ac1a900000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), incentives, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[]));
	}

	function getRewardsByAsset(Currency market) public view returns (Currency[] memory) {
		return getRewardsByAsset(INCENTIVES, market);
	}

	function underlyingToAToken(Currency underlying) public view returns (Currency aToken) {
		(, , , , , , , , aToken, , , , , , ) = getReserveData(LENDING_POOL, underlying);
	}

	function underlyingToVDebtToken(Currency underlying) public view returns (Currency vdToken) {
		(, , , , , , , , , , vdToken, , , , ) = getReserveData(LENDING_POOL, underlying);
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
			uint128 currentLiquidityRate,
			uint128 variableBorrowIndex,
			uint128 currentVariableBorrowRate,
			uint128 currentStableBorrowRate,
			uint40 lastUpdateTimestamp,
			uint16 id,
			Currency aToken,
			Currency stableDebtToken,
			Currency variableDebtToken,
			address interestRateStrategy,
			uint128 accruedToTreasury,
			uint128 unbacked,
			uint128 isolationModeTotalDebt
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

	function getPrice(Currency asset) public view returns (uint256) {
		return getAssetPrice(asset);
	}

	function getPriceFeed(Currency asset) public view returns (address) {
		return getPriceFeed(PRICE_ORACLE, asset);
	}

	function isAssetIn(Currency asset) public view returns (bool) {
		(, , , , , , , uint16 id, , , , , , , ) = getReserveData(LENDING_POOL, asset);

		return isAssetIn(getUserConfiguration(LENDING_POOL), id);
	}

	function isSupplying(Currency asset) public view returns (bool) {
		(, , , , , , , uint16 id, , , , , , , ) = getReserveData(LENDING_POOL, asset);
		return isSupplying(getUserConfiguration(LENDING_POOL), id);
	}

	function isBorrowing(Currency asset) public view returns (bool) {
		(, , , , , , , uint16 id, , , , , , , ) = getReserveData(LENDING_POOL, asset);
		return isBorrowing(getUserConfiguration(LENDING_POOL), id);
	}

	function isAuthorized(address) internal view virtual override returns (bool) {
		return true;
	}

	receive() external payable {}
}
