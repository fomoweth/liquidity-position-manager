// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {MockAaveV2Adapter} from "src/mocks/MockAaveV2Adapter.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vv --match-path test/modules/adapters/lenders/AaveV2Adapter.t.sol

contract AaveV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	MockAaveV2Adapter adapter;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		adapter = new MockAaveV2Adapter(
			address(resolver),
			aaveV2Config.protocol,
			aaveV2Config.lendingPool,
			aaveV2Config.incentives,
			aaveV2Config.oracle,
			aaveV2Config.denomination,
			feedRegistry.getFeed(WETH, USD),
			WRAPPED_NATIVE,
			WETH
		);

		vm.label(address(adapter), "MockAaveV2Adapter");
	}

	function test_enableMarket() public {
		deal(WETH, address(adapter), 1 ether);

		adapter.supply(abi.encode(WETH, 1 ether));

		assertTrue(adapter.isSupplying(WETH));

		adapter.exitMarket(abi.encode(WETH));

		assertFalse(adapter.isSupplying(WETH));

		adapter.enterMarket(abi.encode(WETH));

		assertTrue(adapter.isSupplying(WETH));
	}

	function test_lendingActions_WETH_WBTC() public {
		simulate(WETH, WBTC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WETH_DAI() public {
		simulate(WETH, DAI, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WETH_USDC() public {
		simulate(WETH, USDC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WETH_USDT() public {
		simulate(WETH, USDT, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WETH_FRAX() public {
		simulate(WETH, FRAX, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_WETH() public {
		simulate(WBTC, WETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_DAI() public {
		simulate(WBTC, DAI, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_USDC() public {
		simulate(WBTC, USDC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_USDT() public {
		simulate(WBTC, USDT, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_FRAX() public {
		simulate(WBTC, FRAX, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_WETH() public {
		simulate(DAI, WETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_WBTC() public {
		simulate(DAI, WBTC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_USDC() public {
		simulate(DAI, USDC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_USDT() public {
		simulate(DAI, USDT, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_FRAX() public {
		simulate(DAI, FRAX, 10 ether, 5000, 2500, 60);
	}

	function simulate(
		Currency collateralAsset,
		Currency borrowAsset,
		uint256 ethAmount,
		uint256 collateralUsage,
		uint256 debtRatio,
		uint256 duration
	) internal {
		Currency aToken = adapter.underlyingToAToken(collateralAsset);
		uint256 ltv = adapter.getLtv(collateralAsset);
		uint256 collateralUnit = collateralAsset.decimals();

		Currency vdToken = adapter.underlyingToVDebtToken(borrowAsset);
		uint256 borrowUnit = borrowAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			adapter.getPrice(collateralAsset),
			collateralUnit,
			adapter.getPrice(borrowAsset),
			borrowUnit,
			ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(adapter), supplyAmount);

		adapter.supply(abi.encode(collateralAsset, supplyAmount));
		assertApproxEqAbs(supplyAmount, aToken.balanceOf(address(adapter)), 10);

		assertTrue(
			adapter.isAssetIn(collateralAsset) &&
				adapter.isSupplying(collateralAsset) &&
				!adapter.isBorrowing(collateralAsset)
		);

		adapter.borrow(abi.encode(borrowAsset, borrowAmount));
		assertApproxEqAbs(borrowAmount, vdToken.balanceOf(address(adapter)), 10);

		assertTrue(
			adapter.isAssetIn(borrowAsset) &&
				!adapter.isSupplying(borrowAsset) &&
				adapter.isBorrowing(borrowAsset)
		);

		vm.warp(vm.getBlockTimestamp() + (duration * 1 days));

		uint256 collaterals = aToken.balanceOf(address(adapter));
		uint256 debt = vdToken.balanceOf(address(adapter));

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			collaterals,
			adapter.getPrice(collateralAsset),
			collateralUnit,
			debt,
			adapter.getPrice(borrowAsset),
			borrowUnit,
			ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowBalance = borrowAsset.balanceOf(address(adapter));
		if (borrowBalance < repayAmount) repayAmount = borrowBalance;

		adapter.repay(abi.encode(borrowAsset, repayAmount));
		assertApproxEqAbs(debt - repayAmount, vdToken.balanceOf(address(adapter)), 10);

		adapter.redeem(abi.encode(collateralAsset, redeemAmount));
		assertApproxEqAbs(collaterals - redeemAmount, aToken.balanceOf(address(adapter)), 10);
	}
}
