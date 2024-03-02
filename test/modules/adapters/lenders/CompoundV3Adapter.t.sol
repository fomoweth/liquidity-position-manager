// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {MockCompoundV3Adapter} from "src/mocks/MockCompoundV3Adapter.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vvv --match-path test/modules/adapters/lenders/CompoundV3Adapter.t.sol

contract CompoundV3AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	MockCompoundV3Adapter adapter;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		vm.label(
			address(
				adapter = new MockCompoundV3Adapter(
					address(resolver),
					compV3Config.protocol,
					compV3Config.configurator,
					compV3Config.rewards,
					feedRegistry.getFeed(WETH, USD),
					WRAPPED_NATIVE,
					WETH
				)
			),
			"MockCompoundV3Adapter"
		);
	}

	function test_lendingActions_WETH_USDC() public {
		simulate(compV3Config.cUSDC, WETH);
	}

	function test_lendingActions_WBTC_USDC() public {
		simulate(compV3Config.cUSDC, WBTC);
	}

	function test_lendingActions_LINK_USDC() public {
		simulate(compV3Config.cUSDC, LINK);
	}

	function test_lendingActions_UNI_USDC() public {
		simulate(compV3Config.cUSDC, UNI);
	}

	function test_lendingActions_CBETH_WETH() public {
		simulate(compV3Config.cWETH, cbETH);
	}

	function test_lendingActions_WSTETH_WETH() public {
		simulate(compV3Config.cWETH, wstETH);
	}

	function test_lendingActions_RETH_WETH() public {
		simulate(compV3Config.cWETH, rETH);
	}

	function simulate(Currency comet, Currency collateralAsset) internal {
		uint256 ethAmount = 5 ether;
		uint256 collateralUsage = 7000;
		uint256 debtRatio = 3500;
		uint256 duration = 60;

		uint256 ltv = adapter.getLtv(comet, collateralAsset);
		assertGt(ltv, 0);

		uint256 collateralUnit = collateralAsset.decimals();

		Currency baseAsset = adapter.getBaseAsset(comet);
		uint256 baseUnit = baseAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			adapter.getPrice(comet, collateralAsset),
			collateralUnit,
			adapter.getPrice(comet, baseAsset),
			baseUnit,
			ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(adapter), supplyAmount);

		adapter.supply(abi.encode(comet, collateralAsset, supplyAmount));

		assertApproxEqAbs(supplyAmount, adapter.getCollateralBalance(comet, collateralAsset), 5);

		adapter.borrow(abi.encode(comet, baseAsset, borrowAmount));

		assertApproxEqAbs(borrowAmount, adapter.getBorrowBalance(comet), 5);

		vm.warp(vm.getBlockTimestamp() + (duration * 1 days));

		uint256 collaterals = adapter.getCollateralBalance(comet, collateralAsset);
		uint256 debt = adapter.getBorrowBalance(comet);

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			collaterals,
			adapter.getPrice(comet, collateralAsset),
			collateralUnit,
			debt,
			adapter.getPrice(comet, baseAsset),
			baseUnit,
			ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowBalance = baseAsset.balanceOf(address(adapter));
		if (borrowBalance < repayAmount) repayAmount = borrowBalance;

		adapter.repay(abi.encode(comet, baseAsset, repayAmount));

		assertApproxEqAbs(debt - repayAmount, adapter.getBorrowBalance(comet), 5);

		adapter.redeem(abi.encode(comet, collateralAsset, redeemAmount));

		assertApproxEqAbs(
			collaterals - redeemAmount,
			adapter.getCollateralBalance(comet, collateralAsset),
			5
		);
	}
}
