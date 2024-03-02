// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStaker} from "src/interfaces/IStaker.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {MockConvexCurveAdapter} from "src/mocks/MockConvexCurveAdapter.sol";
import {Reward} from "test/shared/states/DataTypes.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vvv --match-path test/modules/adapters/stakers/ConvexCurveAdapter.t.sol

abstract contract ConvexCurveAdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	MockConvexCurveAdapter adapter;

	function setUp() public virtual override {
		vm.label(
			address(
				adapter = new MockConvexCurveAdapter(address(resolver), CVX_ID, WRAPPED_NATIVE, CRV, CVX)
			),
			"MockConvexCurveAdapter"
		);
	}

	function simulate(
		address pool,
		uint256 pid,
		uint256 offset,
		uint256 length,
		bool useUnderlying,
		Currency[] memory rewardTokens
	) internal {
		uint256 ethAmount = 10 ether;
		uint256 duration = 90;

		assertEq(
			keccak256(abi.encode(adapter.getRewardsList(abi.encode(pid)))),
			keccak256(abi.encode(rewardTokens))
		);

		Currency asset = poolAssets(pool, offset, useUnderlying);

		(Currency rewardPool, , Currency lpToken, , , ) = adapter.getPoolInfo(pid);

		uint256 price = feedRegistry.latestAnswerETH(asset);
		uint256 amount = convertFromETH(ethAmount, price, asset.decimals());
		uint256 liquidity = calcTokenAmount(pool, offset, length, amount, true);

		deal(lpToken, address(adapter), liquidity, true);

		adapter.stake(abi.encode(pid, liquidity));

		assertEq(liquidity, rewardPool.balanceOf(address(adapter)));

		vm.warp(vm.getBlockTimestamp() + (duration * 1 days));

		if (vm.activeFork() != mainnetFork) adapter.userCheckpoint(rewardPool);

		IStaker.PendingReward[] memory pendingRewards = adapter.getPendingRewards(abi.encode(pid));

		Reward[] memory rewards = new Reward[](pendingRewards.length);

		for (uint256 i; i < pendingRewards.length; ++i) {
			rewards[i] = Reward(
				pendingRewards[i].asset,
				pendingRewards[i].amount,
				pendingRewards[i].asset.balanceOf(address(adapter))
			);
		}

		uint256 snapshot = vm.snapshot();

		adapter.getRewards(abi.encode(pid));

		verifyClaim(rewards);

		vm.revertTo(snapshot);

		uint256 staked = rewardPool.balanceOf(address(adapter));

		adapter.unstake(abi.encode(pid, staked));

		verifyClaim(rewards);

		uint256 lpBalance = lpToken.balanceOf(address(adapter));

		assertEq(lpBalance, staked);
	}

	function verifyClaim(Reward[] memory rewards) internal {
		assertTrue(true);

		for (uint256 i; i < rewards.length; ++i) {
			Currency rewardAsset = rewards[i].asset;

			uint256 accrued = rewards[i].accrued;
			uint256 balancePrior = rewards[i].balance;
			uint256 balanceNew = rewardAsset.balanceOf(address(adapter));
			uint256 claimed = balanceNew - balancePrior;

			assertEq(claimed, accrued);
		}
	}
}

contract ConvexCurveAdapterTestMainnet is ConvexCurveAdapterTest {
	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);
		super.setUp();
	}

	function test_stakingActions_3CRV() public {
		simulate(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7, 9, 0, 3, false, setCurrencies(CRV, CVX));
	}

	function test_stakingActions_FRAXBP() public {
		simulate(0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2, 100, 0, 2, false, setCurrencies(CRV, CVX));
	}

	function test_stakingActions_a3CRV() public {
		simulate(
			0xDeBF20617708857ebe4F679508E7b7863a8A8EeE,
			24,
			0,
			3,
			true,
			setCurrencies(CRV, CVX, toCurrency(0x4da27a545c0c5B758a6BA100e3a049001de870f5))
		);
	}

	function test_stakingActions_FRAX3CRV() public {
		simulate(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B, 32, 0, 2, false, setCurrencies(CRV, CVX, FXS));
	}

	function test_stakingActions_MIM3CRV() public {
		simulate(
			0x5a6A4D54456819380173272A5E8E9B9904BdF41B,
			40,
			0,
			2,
			false,
			setCurrencies(CRV, CVX, toCurrency(0x090185f2135308BaD17527004364eBcC2D37e5F6))
		);
	}

	function test_stakingActions_stETH() public {
		simulate(
			0xDC24316b9AE028F1497c275EB9192a3Ea0f67022,
			25,
			0,
			2,
			false,
			setCurrencies(CRV, CVX, toCurrency(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32), wstETH)
		);
	}

	function test_stakingActions_cbETH() public {
		simulate(0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A, 127, 0, 2, false, setCurrencies(CRV, CVX));
	}

	function test_stakingActions_rETH() public {
		simulate(0x0f3159811670c117c372428D4E69AC32325e4D0F, 154, 0, 2, false, setCurrencies(CRV, CVX));
	}
}

contract ConvexCurveAdapterTestPolygon is ConvexCurveAdapterTest {
	function setUp() public virtual override {
		_setUp(POLYGON_CHAIN_ID, true);
		super.setUp();
	}

	function test_stakingActions_am3CRV_Polygon() public {
		simulate(0x445FE580eF8d70FF569aB36e80c647af338db351, 2, 0, 3, true, setCurrencies(CRV, CVX));
	}

	// function test_stakingActions_amTricrypto_Polygon() public {
	// 	simulate(
	// 		0x92215849c439E1f8612b6646060B4E3E5ef822cC,
	// 		3,
	// 		2,
	// 		3,
	// 		false,
	// 		setCurrencies(CRV, CVX)
	// 	);
	// }

	function test_stakingActions_amTricryptoMatic_Polygon() public {
		simulate(0x7BBc0e92505B485aeb3e82E828cb505DAf1E50c6, 9, 0, 2, false, setCurrencies(CRV, CVX));
	}
}

contract ConvexCurveAdapterTestArbitrum is ConvexCurveAdapterTest {
	function setUp() public virtual override {
		_setUp(ARBITRUM_CHAIN_ID, true);
		super.setUp();
	}

	function test_stakingActions_2CRV_Arbitrum() public {
		simulate(0x7f90122BF0700F9E7e1F688fe926940E8839F353, 7, 1, 2, false, setCurrencies(CRV, CVX, ARB));
	}

	function test_stakingActions_FRAXBP_Arbitrum() public {
		simulate(0xC9B8a3FDECB9D5b218d02555a8Baf332E5B740d5, 10, 0, 2, false, setCurrencies(CRV, CVX));
	}

	function test_stakingActions_frxETH_Arbitrum() public {
		simulate(
			0x1DeB3b1cA6afca0FF9C5cE9301950dC98Ac0D523,
			14,
			0,
			2,
			false,
			setCurrencies(CRV, toCurrency(0xaAFcFD42c9954C6689ef1901e03db742520829c5))
		);
	}
}
