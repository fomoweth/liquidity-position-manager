// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockLendingDispatcher} from "src/mocks/MockLendingDispatcher.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vvv --match-path test/modules/adapters/LendingDispatcher.t.sol

contract LendingDispatcherTest is BaseTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	MockLendingDispatcher dispatcher;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		vm.label(
			address(
				dispatcher = new MockLendingDispatcher(
					address(resolver),
					bytes32(bytes("LENDING_DISPATCHER")),
					WRAPPED_NATIVE,
					address(this)
				)
			),
			"MockLendingDispatcher"
		);
	}

	function test_lendingActionsAaveV2() public {
		simulate(
			AAVE_V2_ID,
			toCurrency(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e), // aWETH
			WETH,
			toCurrency(0x619beb58998eD2278e08620f97007e1116D5D25b), // variableDebtUSDC
			USDC
		);
	}

	function test_lendingActionsAaveV3() public {
		simulate(
			AAVE_V3_ID,
			toCurrency(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8), // aEthWETH
			WETH,
			toCurrency(0x72E95b8931767C79bA4EeE721354d6E99a61D004), // variableDebtEthUSDC
			USDC
		);
	}

	function test_lendingActionsCompoundV2() public {
		simulate(
			COMP_V2_ID,
			toCurrency(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5), // cETH
			WETH,
			toCurrency(0x39AA39c021dfbaE8faC545936693aC917d5E7563), // cUSDC
			USDC
		);
	}

	function test_lendingActionsCompoundV3() public {
		simulate(
			COMP_V3_ID,
			toCurrency(0xc3d688B66703497DAA19211EEdff47f25384cdc3), // cUSDCv3
			WETH,
			toCurrency(0xc3d688B66703497DAA19211EEdff47f25384cdc3), // cUSDCv3
			USDC
		);
	}

	function simulate(
		bytes32 key,
		Currency collateralMarket,
		Currency collateralAsset,
		Currency borrowMarket,
		Currency borrowAsset
	) internal {
		uint256 collateralUsage = 5000;
		uint256 debtRatio = 5000;
		uint256 duration = 30;
		uint256 ethAmount = 15 ether;

		uint256 ltv = dispatcher.getLtv(key, collateralMarket, collateralAsset);
		assertGt(ltv, 0);

		uint256 collateralUnit = collateralAsset.decimals();
		uint256 borrowUnit = borrowAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			dispatcher.getAssetPrice(key, collateralMarket, collateralAsset),
			collateralUnit,
			dispatcher.getAssetPrice(key, borrowMarket, borrowAsset),
			borrowUnit,
			ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(dispatcher), supplyAmount);

		dispatcher.supply(key, abi.encode(abi.encode(collateralMarket, collateralAsset, supplyAmount)));

		assertApproxEqAbs(
			supplyAmount,
			dispatcher.getSupplyBalance(key, collateralMarket, collateralAsset),
			supplyAmount.percentMul(1)
		);

		dispatcher.borrow(key, abi.encode(abi.encode(borrowMarket, borrowAsset, borrowAmount)));

		assertApproxEqAbs(
			borrowAmount,
			dispatcher.getBorrowBalance(key, borrowMarket, borrowAsset),
			borrowAmount.percentMul(1)
		);

		vm.warp(vm.getBlockTimestamp() + (duration * 1 days));

		uint256 collaterals = dispatcher.getSupplyBalance(key, collateralMarket, collateralAsset);
		uint256 debt = dispatcher.getBorrowBalance(key, borrowMarket, borrowAsset);

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			collaterals,
			dispatcher.getAssetPrice(key, collateralMarket, collateralAsset),
			collateralUnit,
			debt,
			dispatcher.getAssetPrice(key, borrowMarket, borrowAsset),
			borrowUnit,
			ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowBalance = borrowAsset.balanceOf(address(dispatcher));
		if (borrowBalance < repayAmount) repayAmount = borrowBalance;

		dispatcher.repay(key, abi.encode(abi.encode(borrowMarket, borrowAsset, repayAmount)));

		assertApproxEqAbs(
			debt - repayAmount,
			dispatcher.getBorrowBalance(key, borrowMarket, borrowAsset),
			(debt - repayAmount).percentMul(1)
		);

		dispatcher.redeem(key, abi.encode(abi.encode(collateralMarket, collateralAsset, redeemAmount)));

		assertApproxEqAbs(
			collaterals - redeemAmount,
			dispatcher.getSupplyBalance(key, collateralMarket, collateralAsset),
			(collaterals - redeemAmount).percentMul(1)
		);
	}
}
