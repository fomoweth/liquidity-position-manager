// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {MockCurveAdapter} from "src/mocks/MockCurveAdapter.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vvv --match-path test/modules/adapters/stakers/CurveAdapter.t.sol

contract CurveAdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	MockCurveAdapter adapter;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		vm.label(
			address(adapter = new MockCurveAdapter(address(resolver), CVX_ID, WRAPPED_NATIVE, CRV)),
			"MockCurveAdapter"
		);
	}

	function test_stakingActions_3CRV() public {
		simulate(
			0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7,
			toCurrency(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490),
			toCurrency(0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A),
			0,
			3,
			false,
			setCurrencies(CRV)
		);
	}

	function test_stakingActions_FRAXBP() public {
		simulate(
			0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2,
			toCurrency(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC),
			toCurrency(0xCFc25170633581Bf896CB6CDeE170e3E3Aa59503),
			0,
			2,
			false,
			setCurrencies(CRV)
		);
	}

	function test_stakingActions_a3CRV() public {
		simulate(
			0xDeBF20617708857ebe4F679508E7b7863a8A8EeE,
			toCurrency(0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900),
			toCurrency(0xd662908ADA2Ea1916B3318327A97eB18aD588b5d),
			0,
			3,
			true,
			setCurrencies(CRV, toCurrency(0x4da27a545c0c5B758a6BA100e3a049001de870f5))
		);
	}

	function test_stakingActions_FRAX3CRV() public {
		simulate(
			0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B,
			toCurrency(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B),
			toCurrency(0x72E158d38dbd50A483501c24f792bDAAA3e7D55C),
			0,
			2,
			false,
			setCurrencies(CRV, FXS)
		);
	}

	function test_stakingActions_MIM3CRV() public {
		simulate(
			0x5a6A4D54456819380173272A5E8E9B9904BdF41B,
			toCurrency(0x5a6A4D54456819380173272A5E8E9B9904BdF41B),
			toCurrency(0xd8b712d29381748dB89c36BCa0138d7c75866ddF),
			0,
			2,
			false,
			setCurrencies(CRV, toCurrency(0x090185f2135308BaD17527004364eBcC2D37e5F6))
		);
	}

	function test_stakingActions_stETH() public {
		simulate(
			0xDC24316b9AE028F1497c275EB9192a3Ea0f67022,
			toCurrency(0x06325440D014e39736583c165C2963BA99fAf14E),
			toCurrency(0x182B723a58739a9c974cFDB385ceaDb237453c28),
			0,
			2,
			false,
			setCurrencies(CRV, toCurrency(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32), wstETH)
		);
	}

	function test_stakingActions_cbETH() public {
		simulate(
			0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A,
			toCurrency(0x5b6C539b224014A09B3388e51CaAA8e354c959C8),
			toCurrency(0xAd96E10123Fa34a01cf2314C42D75150849C9295),
			0,
			2,
			false,
			setCurrencies(CRV)
		);
	}

	function simulate(
		address pool,
		Currency token,
		Currency gauge,
		uint256 offset,
		uint256 length,
		bool useUnderlying,
		Currency[] memory rewardTokens
	) internal {
		uint256 ethAmount = 15 ether;
		uint256 duration = 30;

		assertEq(
			keccak256(abi.encode(adapter.getRewardsList(abi.encode(gauge)))),
			keccak256(abi.encode(rewardTokens))
		);

		Currency asset = poolAssets(pool, offset, useUnderlying);
		uint256 price = feedRegistry.latestAnswerETH(asset);
		uint256 amount = convertFromETH(ethAmount, price, asset.decimals());
		uint256 liquidity = calcTokenAmount(pool, offset, length, amount, true);

		deal(token, address(adapter), liquidity, true);

		adapter.stake(abi.encode(token, gauge, liquidity));

		assertEq(liquidity, gauge.balanceOf(address(adapter)));

		warp(duration);

		uint256[] memory rewardsPrior = fetchBalances(rewardTokens, address(adapter));

		uint256 snapshot = vm.snapshot();

		adapter.getRewards(abi.encode(gauge));

		verifyClaim(rewardTokens, rewardsPrior);

		vm.revertTo(snapshot);

		uint256 staked = gauge.balanceOf(address(adapter));

		adapter.unstake(abi.encode(gauge, staked));

		verifyClaim(rewardTokens, rewardsPrior);

		uint256 lpBalance = token.balanceOf(address(adapter));
		assertEq(lpBalance, staked);
	}

	function verifyClaim(Currency[] memory rewardTokens, uint256[] memory rewardsPrior) internal {
		uint256[] memory rewardsNew = fetchBalances(rewardTokens, address(adapter));

		for (uint256 i; i < rewardsPrior.length; ++i) {
			if (rewardsNew[i] != 0) {
				assertGt(rewardsNew[i], rewardsPrior[i]);
			}
		}
	}
}
