// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CompoundV3Adapter} from "src/modules/adapters/lenders/CompoundV3Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockCompoundV3Adapter is CompoundV3Adapter {
	using CurrencyLibrary for Currency;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _configurator,
		address _rewards,
		address _ethUsdFeed,
		Currency _wrappedNative,
		Currency _weth
	) CompoundV3Adapter(_resolver, _protocol, _configurator, _rewards, _ethUsdFeed, _wrappedNative, _weth) {}

	function getBorrowBalance(Currency comet) public view returns (uint256 borrowBalance) {
		return borrowBalanceOf(comet);
	}

	function getCollateralBalance(
		Currency comet,
		Currency asset
	) public view returns (uint256 collateralBalance) {
		return collateralBalanceOf(comet, asset);
	}

	function getPrice(Currency comet, Currency asset) public view returns (uint256) {
		return getAssetPrice(comet, asset);
	}

	function getLtv(Currency comet, Currency asset) public view returns (uint256 ltv) {
		(, , , ltv, , , ) = getAssetInfo(comet, asset);
	}

	function getAssetInfo(
		Currency comet,
		Currency asset
	)
		public
		view
		returns (
			uint8 offset,
			address priceFeed,
			uint16 scale,
			uint16 borrowCollateralFactor,
			uint16 liquidateCollateralFactor,
			uint16 liquidationFactor,
			uint128 supplyCap
		)
	{
		return getAssetInfoByAddress(comet, asset);
	}

	function getAssetConfigs(Currency comet) public view returns (AssetConfig[] memory) {
		return getConfiguration(CONFIGURATOR, comet).assetConfigs;
	}

	function getConfiguration(Currency comet) public view returns (Configuration memory) {
		return getConfiguration(CONFIGURATOR, comet);
	}

	function getBaseAsset(Currency comet) public view returns (Currency) {
		return baseToken(comet);
	}

	function getBaseFeed(Currency comet) public view returns (address) {
		return baseTokenPriceFeed(comet);
	}

	function getReservesList(Currency comet) public view returns (Currency[] memory assets) {
		AssetConfig[] memory assetConfigs = getConfiguration(CONFIGURATOR, comet).assetConfigs;

		assets = new Currency[](assetConfigs.length);

		for (uint256 i; i < assetConfigs.length; ++i) {
			assets[i] = assetConfigs[i].asset;
		}
	}

	function getRewardAsset(Currency comet) public view returns (Currency rewardAsset) {
		(rewardAsset, , ) = rewardConfig(REWARDS, comet);
	}

	receive() external payable {}
}
