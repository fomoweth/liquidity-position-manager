// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {MockAaveV2Adapter} from "src/mocks/MockAaveV2Adapter.sol";
import {AaveMarket} from "test/shared/states/DataTypes.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vv --match-path test/modules/adapters/lenders/AaveV2Adapter.t.sol

contract AaveV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	MockAaveV2Adapter adapter;

	AaveMarket wethMarket;
	AaveMarket daiMarket;

	Currency rewardAsset;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		deployConfigurations();

		adapter = new MockAaveV2Adapter(
			address(resolver),
			aaveV2Config.protocol,
			aaveV2Config.lendingPool,
			aaveV2Config.incentives,
			aaveV2Config.oracle,
			aaveV2Config.denomination,
			WRAPPED_NATIVE,
			WETH
		);

		wethMarket = getAaveMarket(WETH, false);
		daiMarket = getAaveMarket(DAI, false);

		rewardAsset = adapter.getRewardAsset();

		vm.label(rewardAsset.toAddress(), symbol(rewardAsset));
	}

	function test_enableMarket() public {
		deal(wethMarket.underlying, address(adapter), 1 ether);

		adapter.supply(wethMarket.aToken, wethMarket.underlying, 1 ether);

		assertTrue(adapter.isSupplying(wethMarket.underlying));

		adapter.exitMarket(wethMarket.underlying);

		assertTrue(!adapter.isSupplying(wethMarket.underlying));

		adapter.enterMarket(wethMarket.underlying);

		assertTrue(adapter.isSupplying(wethMarket.underlying));
	}

	function test_lendingActions_WETH_to_DAI() public {
		uint256 ethAmount = 10 ether;
		uint256 collateralUsage = 5000;
		uint256 debtRatio = 2500;
		uint256 duration = 30 days;

		Currency collateralAsset = wethMarket.underlying;
		Currency aToken = wethMarket.aToken;
		uint256 collateralUnit = collateralAsset.decimals();

		Currency borrowAsset = daiMarket.underlying;
		Currency vdToken = daiMarket.vdToken;
		uint256 borrowUnit = borrowAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			getAavePrice(collateralAsset, true),
			collateralUnit,
			getAavePrice(borrowAsset, true),
			borrowUnit,
			wethMarket.ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(adapter), supplyAmount);

		adapter.supply(abi.encode(collateralAsset, supplyAmount));

		report("Supply");

		assertTrue(
			adapter.isAssetIn(collateralAsset) &&
				adapter.isSupplying(collateralAsset) &&
				!adapter.isBorrowing(collateralAsset)
		);

		adapter.borrow(abi.encode(borrowAsset, borrowAmount));

		report("Borrow");

		assertTrue(
			adapter.isAssetIn(borrowAsset) &&
				!adapter.isSupplying(borrowAsset) &&
				adapter.isBorrowing(borrowAsset)
		);

		vm.warp(vm.getBlockTimestamp() + duration);

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			aToken.balanceOf(address(adapter)),
			getAavePrice(collateralAsset, true),
			collateralUnit,
			vdToken.balanceOf(address(adapter)),
			getAavePrice(borrowAsset, true),
			borrowUnit,
			wethMarket.ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowBalance = borrowAsset.balanceOf(address(adapter));

		if (borrowBalance < repayAmount) repayAmount = borrowBalance;

		adapter.repay(abi.encode(borrowAsset, repayAmount));

		report("Repay");

		adapter.redeem(abi.encode(collateralAsset, redeemAmount));

		report("Redeem");
	}

	function test_lendingActions_DAI_to_WETH() public {
		uint256 ethAmount = 10 ether;
		uint256 collateralUsage = 5000;
		uint256 debtRatio = 2500;
		uint256 duration = 30 days;

		Currency collateralAsset = daiMarket.underlying;
		Currency aToken = daiMarket.aToken;
		uint256 collateralUnit = collateralAsset.decimals();

		Currency borrowAsset = wethMarket.underlying;
		Currency vdToken = wethMarket.vdToken;
		uint256 borrowUnit = borrowAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			getAavePrice(collateralAsset, true),
			collateralUnit,
			getAavePrice(borrowAsset, true),
			borrowUnit,
			daiMarket.ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(adapter), supplyAmount);

		adapter.supply(abi.encode(collateralAsset, supplyAmount));

		assertTrue(
			adapter.isAssetIn(collateralAsset) &&
				adapter.isSupplying(collateralAsset) &&
				!adapter.isBorrowing(collateralAsset)
		);

		report("Supply");

		adapter.borrow(abi.encode(borrowAsset, borrowAmount));

		assertTrue(
			adapter.isAssetIn(borrowAsset) &&
				!adapter.isSupplying(borrowAsset) &&
				adapter.isBorrowing(borrowAsset)
		);

		report("Borrow");

		vm.warp(vm.getBlockTimestamp() + duration);

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			aToken.balanceOf(address(adapter)),
			getAavePrice(collateralAsset, true),
			collateralUnit,
			vdToken.balanceOf(address(adapter)),
			getAavePrice(borrowAsset, true),
			borrowUnit,
			daiMarket.ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowBalance = borrowAsset.balanceOf(address(adapter));

		if (borrowBalance < repayAmount) repayAmount = borrowBalance;

		adapter.repay(abi.encode(borrowAsset, repayAmount));

		report("Repay");

		adapter.redeem(abi.encode(collateralAsset, redeemAmount));

		report("Redeem");
	}

	function report(string memory title) internal view {
		(
			uint256 totalCollateral,
			uint256 totalDebt,
			uint256 availableBorrows,
			uint256 currentLiquidationThreshold,
			uint256 ltv,
			uint256 healthFactor
		) = adapter.getUserAccountData();

		console.log(title);
		console.log("");
		console.log("totalCollateral:", totalCollateral);
		console.log("totalDebt:", totalDebt);
		console.log("availableBorrows:", availableBorrows);
		console.log("currentLiquidationThreshold:", currentLiquidationThreshold);
		console.log("ltv:", ltv);
		console.log("healthFactor:", healthFactor);
		console.log("");
	}
}
