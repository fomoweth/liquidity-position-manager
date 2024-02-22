// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {MockAaveV3Adapter} from "src/mocks/MockAaveV3Adapter.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vv --match-path test/modules/adapters/lenders/AaveV3Adapter.t.sol

contract AaveV3AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	MockAaveV3Adapter adapter;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		adapter = new MockAaveV3Adapter(
			address(resolver),
			aaveV3Config.protocol,
			aaveV3Config.lendingPool,
			aaveV3Config.incentives,
			aaveV3Config.oracle,
			aaveV3Config.denomination,
			feedRegistry.getFeed(WETH, USD),
			WRAPPED_NATIVE,
			WETH
		);

		vm.label(address(adapter), "MockAaveV3Adapter");
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

	function test_lendingActions_WETH_WSTETH() public {
		simulate(WETH, wstETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WETH_CBETH() public {
		simulate(WETH, cbETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WETH_RETH() public {
		simulate(WETH, rETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WETH_LINK() public {
		simulate(WETH, LINK, 10 ether, 5000, 2500, 60);
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

	function test_lendingActions_WBTC_WETH() public {
		simulate(WBTC, WETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_WSTETH() public {
		simulate(WBTC, wstETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_CBETH() public {
		simulate(WBTC, cbETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_RETH() public {
		simulate(WBTC, rETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WBTC_LINK() public {
		simulate(WBTC, LINK, 10 ether, 5000, 2500, 60);
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

	function test_lendingActions_WSTETH_WETH() public {
		simulate(wstETH, WETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WSTETH_CBETH() public {
		simulate(wstETH, cbETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WSTETH_RETH() public {
		simulate(wstETH, rETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WSTETH_WBTC() public {
		simulate(wstETH, WBTC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WSTETH_LINK() public {
		simulate(wstETH, LINK, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WSTETH_DAI() public {
		simulate(wstETH, DAI, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WSTETH_USDC() public {
		simulate(wstETH, USDC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_WSTETH_USDT() public {
		simulate(wstETH, USDT, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_WETH() public {
		simulate(cbETH, WETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_WSTETH() public {
		simulate(cbETH, wstETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_RETH() public {
		simulate(cbETH, rETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_WBTC() public {
		simulate(cbETH, WBTC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_LINK() public {
		simulate(cbETH, LINK, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_DAI() public {
		simulate(cbETH, DAI, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_USDC() public {
		simulate(cbETH, USDC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_CBETH_USDT() public {
		simulate(cbETH, USDT, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_WETH() public {
		simulate(rETH, WETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_WSTETH() public {
		simulate(rETH, wstETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_CBETH() public {
		simulate(rETH, cbETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_WBTC() public {
		simulate(rETH, WBTC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_LINK() public {
		simulate(rETH, LINK, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_DAI() public {
		simulate(rETH, DAI, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_USDC() public {
		simulate(rETH, USDC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_RETH_USDT() public {
		simulate(rETH, USDT, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_WETH() public {
		simulate(DAI, WETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_WSTETH() public {
		simulate(DAI, wstETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_CBETH() public {
		simulate(DAI, cbETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_RETH() public {
		simulate(DAI, rETH, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_WBTC() public {
		simulate(DAI, WBTC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_LINK() public {
		simulate(DAI, LINK, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_USDC() public {
		simulate(DAI, USDC, 10 ether, 5000, 2500, 60);
	}

	function test_lendingActions_DAI_USDT() public {
		simulate(DAI, USDT, 10 ether, 5000, 2500, 60);
	}

	function simulate(
		Currency collateralAsset,
		Currency borrowAsset,
		uint256 ethAmount,
		uint256 collateralUsage,
		uint256 debtRatio,
		uint256 duration
	) internal {
		ethAmount = bound(ethAmount, 1 ether, 20 ether);
		collateralUsage = bound(collateralUsage, 1000, 9000);
		debtRatio = bound(debtRatio, 1000, 10000);
		duration = bound(duration, 1, 90);

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
