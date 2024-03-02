// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {MockCompoundV2Adapter} from "src/mocks/MockCompoundV2Adapter.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vvv --match-path test/modules/adapters/lenders/CompoundV2Adapter.t.sol

contract CompoundV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	MockCompoundV2Adapter adapter;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		vm.label(
			address(
				adapter = new MockCompoundV2Adapter(
					address(resolver),
					address(cTokenRegistry),
					compV2Config.protocol,
					compV2Config.comptroller,
					compV2Config.oracle,
					compV2Config.cNative,
					compV2Config.cETH,
					feedRegistry.getFeed(WETH, USD),
					WRAPPED_NATIVE,
					WETH
				)
			),
			"MockCompoundV2Adapter"
		);
	}

	function test_enableMarket() public {
		Currency cETH = cTokenRegistry.cETH();

		deal(WETH, address(adapter), 1 ether);

		adapter.supply(abi.encode(cETH, WETH, 1 ether));

		assertTrue(adapter.checkMembership(cETH));

		adapter.exitMarket(abi.encode(cETH));

		assertFalse(adapter.checkMembership(cETH));

		adapter.enterMarket(abi.encode(cETH));

		assertTrue(adapter.checkMembership(cETH));
	}

	function test_supplyAndBorrow() public {
		Currency cETH = cTokenRegistry.underlyingToCToken(WETH);
		Currency cDAI = cTokenRegistry.underlyingToCToken(DAI);
		Currency cWBTC = cTokenRegistry.underlyingToCToken(WBTC);
		Currency cUSDT = cTokenRegistry.underlyingToCToken(USDT);

		(uint256 ethSupply, uint256 daiBorrow) = getSupplyAndBorrowAmounts(
			adapter.getPrice(cETH),
			18,
			adapter.getPrice(cDAI),
			18,
			adapter.getLtv(cETH),
			5000,
			10 ether
		);

		deal(WETH, address(adapter), ethSupply);

		adapter.supply(abi.encode(cETH, WETH, ethSupply));

		assertApproxEqAbs(ethSupply, adapter.getSupplyBalance(cETH), ethSupply.percentMul(1));
		assertTrue(adapter.checkMembership(cETH));

		adapter.borrow(abi.encode(cDAI, DAI, daiBorrow));

		assertApproxEqAbs(daiBorrow, adapter.getBorrowBalance(cDAI), daiBorrow.percentMul(1));
		assertTrue(adapter.checkMembership(cDAI));

		(uint256 wbtcSupply, uint256 usdtBorrow) = getSupplyAndBorrowAmounts(
			adapter.getPrice(cWBTC),
			8,
			adapter.getPrice(cUSDT),
			6,
			adapter.getLtv(cWBTC),
			7000,
			15 ether
		);

		deal(WBTC, address(adapter), wbtcSupply);

		adapter.supply(abi.encode(cWBTC, WBTC, wbtcSupply));

		assertApproxEqAbs(wbtcSupply, adapter.getSupplyBalance(cWBTC), wbtcSupply.percentMul(1));
		assertTrue(adapter.checkMembership(cWBTC));

		adapter.borrow(abi.encode(cUSDT, USDT, usdtBorrow));

		assertApproxEqAbs(usdtBorrow, adapter.getBorrowBalance(cUSDT), usdtBorrow.percentMul(1));
		assertTrue(adapter.checkMembership(cUSDT));
	}

	function test_lendingActions_WETH_WBTC() public {
		simulate(WETH, WBTC);
	}

	function test_lendingActions_WETH_LINK() public {
		simulate(WETH, LINK);
	}

	function test_lendingActions_WETH_UNI() public {
		simulate(WETH, UNI);
	}

	function test_lendingActions_WETH_DAI() public {
		simulate(WETH, DAI);
	}

	function test_lendingActions_WETH_USDC() public {
		simulate(WETH, USDC);
	}

	function test_lendingActions_WETH_USDT() public {
		simulate(WETH, USDT);
	}

	function test_lendingActions_WBTC_WETH() public {
		simulate(WBTC, WETH);
	}

	function test_lendingActions_WBTC_LINK() public {
		simulate(WBTC, LINK);
	}

	function test_lendingActions_WBTC_UNI() public {
		simulate(WBTC, UNI);
	}

	function test_lendingActions_WBTC_DAI() public {
		simulate(WBTC, DAI);
	}

	function test_lendingActions_WBTC_USDC() public {
		simulate(WBTC, USDC);
	}

	function test_lendingActions_WBTC_USDT() public {
		simulate(WBTC, USDT);
	}

	function test_lendingActions_DAI_WETH() public {
		simulate(DAI, WETH);
	}

	function test_lendingActions_DAI_WBTC() public {
		simulate(DAI, WBTC);
	}

	function test_lendingActions_DAI_LINK() public {
		simulate(DAI, LINK);
	}

	function test_lendingActions_DAI_UNI() public {
		simulate(DAI, UNI);
	}

	function test_lendingActions_DAI_USDC() public {
		simulate(DAI, USDC);
	}

	function test_lendingActions_DAI_USDT() public {
		simulate(DAI, USDT);
	}

	function simulate(Currency collateralAsset, Currency borrowAsset) internal {
		uint256 ethAmount = 10 ether;
		uint256 collateralUsage = 5000;
		uint256 debtRatio = 2500;
		uint256 duration = 90;

		Currency collateralMarket = cTokenRegistry.underlyingToCToken(collateralAsset);
		uint256 collateralUnit = collateralAsset.decimals();

		uint256 ltv = adapter.getLtv(collateralMarket);
		assertGt(ltv, 0);

		Currency borrowMarket = cTokenRegistry.underlyingToCToken(borrowAsset);
		uint256 borrowUnit = borrowAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			adapter.getPrice(collateralMarket),
			collateralUnit,
			adapter.getPrice(borrowMarket),
			borrowUnit,
			ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(adapter), supplyAmount);

		adapter.supply(abi.encode(collateralMarket, collateralAsset, supplyAmount));

		assertApproxEqAbs(
			supplyAmount,
			adapter.getSupplyBalance(collateralMarket),
			supplyAmount.percentMul(1)
		);
		assertTrue(adapter.checkMembership(collateralMarket));

		adapter.borrow(abi.encode(borrowMarket, borrowAsset, borrowAmount));

		assertApproxEqAbs(borrowAmount, adapter.getBorrowBalance(borrowMarket), borrowAmount.percentMul(1));
		assertTrue(adapter.checkMembership(borrowMarket));

		vm.warp(vm.getBlockTimestamp() + (duration * 1 days));

		uint256 collaterals = adapter.getSupplyBalance(collateralMarket);
		uint256 debt = adapter.getBorrowBalance(borrowMarket);

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			collaterals,
			adapter.getPrice(collateralMarket),
			collateralUnit,
			debt,
			adapter.getPrice(borrowMarket),
			borrowUnit,
			ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowBalance = borrowAsset.balanceOf(address(adapter));
		if (borrowBalance < repayAmount) repayAmount = borrowBalance;

		adapter.repay(abi.encode(borrowMarket, borrowAsset, repayAmount));

		assertApproxEqAbs(
			debt - repayAmount,
			adapter.getBorrowBalance(borrowMarket),
			(debt - repayAmount).percentMul(1)
		);

		adapter.redeem(abi.encode(collateralMarket, collateralAsset, redeemAmount));

		assertApproxEqAbs(
			collaterals - redeemAmount,
			adapter.getSupplyBalance(collateralMarket),
			(collaterals - redeemAmount).percentMul(1)
		);
	}
}
