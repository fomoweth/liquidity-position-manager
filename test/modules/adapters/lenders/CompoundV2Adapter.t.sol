// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {MockCompoundV2Adapter} from "src/mocks/MockCompoundV2Adapter.sol";
import {CompoundMarket} from "test/shared/states/DataTypes.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vv --match-path test/modules/adapters/lenders/CompoundV2Adapter.t.sol

contract CompoundV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;
	using WadRayMath for uint256;

	MockCompoundV2Adapter adapter;

	CompoundMarket ceth;
	CompoundMarket cwbtc;
	CompoundMarket cdai;
	CompoundMarket cusdt;

	Currency rewardAsset;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		deployConfigurations();

		adapter = new MockCompoundV2Adapter(
			address(resolver),
			compV2Config.protocol,
			compV2Config.comptroller,
			compV2Config.oracle,
			compV2Config.cNative,
			compV2Config.cETH,
			WRAPPED_NATIVE,
			WETH
		);

		Currency[] memory assets = new Currency[](4);
		assets[0] = WETH;
		assets[1] = WBTC;
		assets[2] = DAI;
		assets[3] = USDT;

		CompoundMarket[] memory markets = getCTokenMarkets(assets);
		ceth = markets[0];
		cwbtc = markets[1];
		cdai = markets[2];
		cusdt = markets[3];

		rewardAsset = adapter.getRewardAsset();

		vm.label(rewardAsset.toAddress(), symbol(rewardAsset));
	}

	function test_enableMarket() public {
		deal(ceth.underlying, address(adapter), 1 ether);

		adapter.supply(ceth.market, ceth.underlying, 1 ether);

		assertTrue(adapter.checkMembership(ceth.market));

		adapter.exitMarket(ceth.market);

		assertTrue(!adapter.checkMembership(ceth.market));

		adapter.enterMarket(ceth.market);

		assertTrue(adapter.checkMembership(ceth.market));
	}

	function test_supplyAndBorrow() public {
		(uint256 ethSupply, uint256 daiBorrow) = getSupplyAndBorrowAmounts(
			getCompoundPrice(ceth.market, 18),
			18,
			getCompoundPrice(cdai.market, 18),
			18,
			ceth.ltv,
			5000,
			10 ether
		);

		deal(ceth.underlying, address(adapter), ethSupply);

		adapter.supply(ceth.market, ceth.underlying, ethSupply);

		report("Supplied ETH");

		adapter.borrow(cdai.market, cdai.underlying, daiBorrow);

		report("Borrowed DAI");

		(uint256 wbtcSupply, uint256 usdtBorrow) = getSupplyAndBorrowAmounts(
			getCompoundPrice(cwbtc.market, 8),
			8,
			getCompoundPrice(cusdt.market, 6),
			6,
			cwbtc.ltv,
			7000,
			15 ether
		);

		deal(cwbtc.underlying, address(adapter), wbtcSupply);

		adapter.supply(cwbtc.market, cwbtc.underlying, wbtcSupply);

		report("Supplied WBTC");

		adapter.borrow(cusdt.market, cusdt.underlying, usdtBorrow);

		report("Borrowed USDT");
	}

	function test_lendingActions_WETH_to_DAI() public {
		uint256 ethAmount = 10 ether;
		uint256 collateralUsage = 5000;
		uint256 debtRatio = 2500;
		uint256 duration = 30 days;

		Currency collateralMarket = ceth.market;
		Currency collateralAsset = ceth.underlying;
		uint256 collateralUnit = collateralAsset.decimals();
		uint256 ltv = ceth.ltv;

		Currency borrowMarket = cdai.market;
		Currency borrowAsset = cdai.underlying;
		uint256 borrowUnit = borrowAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			getCompoundPrice(collateralMarket, collateralUnit),
			collateralUnit,
			getCompoundPrice(borrowMarket, borrowUnit),
			borrowUnit,
			ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(adapter), supplyAmount);

		adapter.supply(collateralMarket, collateralAsset, supplyAmount);

		report("Supplied ETH");

		adapter.borrow(borrowMarket, borrowAsset, borrowAmount);

		report("Borrowed DAI");

		vm.warp(vm.getBlockTimestamp() + duration);

		(uint256 cTokenBalance, , uint256 exchangeRate) = getAccountSnapshot(
			collateralMarket,
			address(adapter)
		);

		uint256 supplyBalance = cTokenBalance.wadMul(exchangeRate);

		(, uint256 borrowBalance, ) = getAccountSnapshot(borrowMarket, address(adapter));

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			supplyBalance,
			getCompoundPrice(collateralMarket, collateralUnit),
			collateralUnit,
			borrowBalance,
			getCompoundPrice(borrowMarket, borrowUnit),
			borrowUnit,
			ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowAssetHoldings = borrowAsset.balanceOf(address(adapter));

		if (borrowAssetHoldings < repayAmount) repayAmount = borrowAssetHoldings;

		adapter.repay(borrowMarket, borrowAsset, repayAmount);

		report("Repaid DAI");

		adapter.redeem(collateralMarket, collateralAsset, redeemAmount);

		report("Redeemed ETH");
	}

	function test_lendingActions_DAI_to_WETH() public {
		uint256 ethAmount = 10 ether;
		uint256 collateralUsage = 5000;
		uint256 debtRatio = 2500;
		uint256 duration = 30 days;

		Currency collateralMarket = cdai.market;
		Currency collateralAsset = cdai.underlying;
		uint256 collateralUnit = collateralAsset.decimals();
		uint256 ltv = cdai.ltv;

		Currency borrowMarket = ceth.market;
		Currency borrowAsset = ceth.underlying;
		uint256 borrowUnit = borrowAsset.decimals();

		(uint256 supplyAmount, uint256 borrowAmount) = getSupplyAndBorrowAmounts(
			getCompoundPrice(collateralMarket, collateralUnit),
			collateralUnit,
			getCompoundPrice(borrowMarket, borrowUnit),
			borrowUnit,
			ltv,
			collateralUsage,
			ethAmount
		);

		deal(collateralAsset, address(adapter), supplyAmount);

		adapter.supply(collateralMarket, collateralAsset, supplyAmount);

		report("Supplied DAI");

		adapter.borrow(borrowMarket, borrowAsset, borrowAmount);

		report("Borrowed ETH");

		vm.warp(vm.getBlockTimestamp() + duration);

		(uint256 cTokenBalance, , uint256 exchangeRate) = getAccountSnapshot(
			collateralMarket,
			address(adapter)
		);

		uint256 supplyBalance = cTokenBalance.wadMul(exchangeRate);

		(, uint256 borrowBalance, ) = getAccountSnapshot(borrowMarket, address(adapter));

		(uint256 repayAmount, uint256 redeemAmount) = getRepayAndRedeemAmounts(
			supplyBalance,
			getCompoundPrice(collateralMarket, collateralUnit),
			collateralUnit,
			borrowBalance,
			getCompoundPrice(borrowMarket, borrowUnit),
			borrowUnit,
			ltv,
			collateralUsage,
			debtRatio
		);

		uint256 borrowAssetHoldings = borrowAsset.balanceOf(address(adapter));

		if (borrowAssetHoldings < repayAmount) repayAmount = borrowAssetHoldings;

		adapter.repay(borrowMarket, borrowAsset, repayAmount);

		report("Repaid ETH");

		adapter.redeem(collateralMarket, collateralAsset, redeemAmount);

		report("Redeemed DAI");
	}

	function report(string memory title) internal {
		(uint256 liquidity, uint256 shortfall) = getAccountLiquidity(address(adapter));

		assertGt(liquidity, 0);
		assertEq(shortfall, 0);

		(
			uint256 totalCollateral,
			uint256 totalLiability,
			uint256 availableLiquidity,
			uint256 healthFactor
		) = adapter.getAccountLiquidity();

		console.log(title);
		console.log("");
		console.log("liquidity:", liquidity);
		console.log("shortfall:", shortfall);
		console.log("");
		console.log("totalCollateral:", totalCollateral);
		console.log("totalLiability:", totalLiability);
		console.log("availableLiquidity:", availableLiquidity);
		console.log("healthFactor:", healthFactor);
		console.log("");
	}
}
