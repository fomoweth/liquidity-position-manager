// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {UNISWAP_V3_NFT, UNISWAP_V3_STAKER} from "src/libraries/Constants.sol";
import {ERC721Utils} from "src/libraries/ERC721Utils.sol";
import {Incentive} from "src/libraries/Incentive.sol";
import {LiquidityAmounts} from "src/libraries/LiquidityAmounts.sol";
import {TickMath} from "src/libraries/TickMath.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {PoolKey, toPoolKey} from "src/types/PoolKey.sol";
import {MockStakingDispatcher} from "src/mocks/MockStakingDispatcher.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vvv --match-path test/modules/adapters/StakingDispatcher.t.sol

contract StakingDispatcherTest is BaseTest {
	using CurrencyLibrary for Currency;
	using ERC721Utils for address;
	using Incentive for Incentive.Key;

	MockStakingDispatcher dispatcher;

	address crvPool;
	Currency crvToken;
	Currency crvGauge;
	Currency cvxReward;
	Currency cvxToken;
	Currency LDO;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		vm.label(
			address(
				dispatcher = new MockStakingDispatcher(
					address(resolver),
					toBytes32("STAKING_DISPATCHER"),
					WRAPPED_NATIVE,
					address(this)
				)
			),
			"MockStakingDispatcher"
		);

		LDO = setCurrency(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
		crvToken = setCurrency(0x06325440D014e39736583c165C2963BA99fAf14E);
		crvGauge = setCurrency(0x182B723a58739a9c974cFDB385ceaDb237453c28);
		cvxToken = setCurrency(0x9518c9063eB0262D791f38d8d6Eb0aca33c63ed0);

		vm.label(
			(crvPool = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022),
			string.concat(symbol(crvToken), " Pool")
		);

		vm.label(
			(cvxReward = toCurrency(0x0A760466E1B4621579a82a39CB56Dda2F4E70f03)).toAddress(),
			string.concat(symbol(cvxToken), " Pool")
		);
	}

	function test_stakingActionsConvexCurve() public {
		simulateConvexCurve(
			crvPool,
			crvToken,
			cvxReward,
			25,
			0,
			2,
			false,
			setCurrencies(CRV, CVX, LDO, wstETH)
		);
	}

	function test_stakingActionsCurve() public {
		simulateCurve(crvPool, crvToken, crvGauge, 0, 2, false, setCurrencies(CRV, LDO, wstETH));
	}

	function test_stakingActionsUniswapV3() public {
		simulateUniswapV3(DAI, WETH, 3000);
	}

	function simulateConvexCurve(
		address pool,
		Currency lpToken,
		Currency rewardPool,
		uint256 pid,
		uint256 offset,
		uint256 length,
		bool useUnderlying,
		Currency[] memory rewardTokens
	) internal {
		bytes32 key = CVX_ID;
		uint256 ethAmount = 10 ether;
		uint256 duration = 90;

		assertEq(
			keccak256(abi.encode(dispatcher.getRewardsList(key, abi.encode(abi.encode(pid))))),
			keccak256(abi.encode(rewardTokens))
		);

		Currency asset = poolAssets(pool, offset, useUnderlying);

		uint256 price = feedRegistry.latestAnswerETH(asset);
		uint256 amount = convertFromETH(ethAmount, price, asset.decimals());
		uint256 liquidity = calcTokenAmount(pool, offset, length, amount, true);

		deal(lpToken, address(dispatcher), liquidity, true);

		dispatcher.stake(key, abi.encode(abi.encode(pid, liquidity)));

		assertEq(liquidity, rewardPool.balanceOf(address(dispatcher)));

		warp(duration);

		uint256[] memory rewardsPrior = fetchBalances(rewardTokens, address(dispatcher));

		uint256 snapshot = vm.snapshot();

		dispatcher.getRewards(key, abi.encode(abi.encode(pid)));

		verifyClaim(rewardTokens, rewardsPrior);

		vm.revertTo(snapshot);

		uint256 staked = rewardPool.balanceOf(address(dispatcher));

		dispatcher.unstake(key, abi.encode(abi.encode(pid, staked)));

		verifyClaim(rewardTokens, rewardsPrior);

		uint256 lpBalance = lpToken.balanceOf(address(dispatcher));
		assertEq(lpBalance, staked);
	}

	function simulateCurve(
		address pool,
		Currency token,
		Currency gauge,
		uint256 offset,
		uint256 length,
		bool useUnderlying,
		Currency[] memory rewardTokens
	) internal {
		bytes32 key = CRV_ID;
		uint256 ethAmount = 15 ether;
		uint256 duration = 30;

		assertEq(
			keccak256(abi.encode(dispatcher.getRewardsList(key, abi.encode(abi.encode(gauge))))),
			keccak256(abi.encode(rewardTokens))
		);

		Currency asset = poolAssets(pool, offset, useUnderlying);

		uint256 price = feedRegistry.latestAnswerETH(asset);
		uint256 amount = convertFromETH(ethAmount, price, asset.decimals());
		uint256 liquidity = calcTokenAmount(pool, offset, length, amount, true);

		deal(token, address(dispatcher), liquidity, true);

		dispatcher.stake(key, abi.encode(abi.encode(token, gauge, liquidity)));

		assertEq(liquidity, gauge.balanceOf(address(dispatcher)));

		warp(duration);

		uint256[] memory rewardsPrior = fetchBalances(rewardTokens, address(dispatcher));

		uint256 snapshot = vm.snapshot();

		dispatcher.getRewards(key, abi.encode(abi.encode(gauge)));

		verifyClaim(rewardTokens, rewardsPrior);

		vm.revertTo(snapshot);

		uint256 staked = gauge.balanceOf(address(dispatcher));

		dispatcher.unstake(key, abi.encode(abi.encode(gauge, staked)));

		verifyClaim(rewardTokens, rewardsPrior);

		uint256 lpBalance = token.balanceOf(address(dispatcher));
		assertEq(lpBalance, staked);
	}

	function simulateUniswapV3(Currency currency0, Currency currency1, uint24 fee) internal {
		bytes32 key = UNI_V3_ID;
		uint256 ethAmount = 10 ether;
		uint256 duration = 30;

		PoolKey memory poolKey = toPoolKey(currency0, currency1, fee);

		address pool = poolKey.compute();

		Currency[] memory rewardTokens = new Currency[](2);
		rewardTokens[0] = currency0;
		rewardTokens[1] = currency1;

		Incentive.Key memory incentive0 = createIncentive(pool, currency0, 0, 0);
		bytes32 incentive0Id = incentive0.compute();

		Incentive.Key memory incentive1 = createIncentive(pool, currency1, 0, 0);
		bytes32 incentive1Id = incentive1.compute();

		uint256 amount0Desired = convertFromETH(
			ethAmount,
			feedRegistry.latestAnswerETH(currency0),
			currency0.decimals()
		);

		uint256 amount1Desired = convertFromETH(
			ethAmount,
			feedRegistry.latestAnswerETH(currency1),
			currency1.decimals()
		);

		deal(currency0, address(this), amount0Desired);
		deal(currency1, address(this), amount1Desired);

		int24 tickSpacing = poolKey.tickSpacing();
		int24 tickLower = TickMath.minUsableTick(tickSpacing);
		int24 tickUpper = TickMath.maxUsableTick(tickSpacing);

		(, uint256 amount0, uint256 amount1) = getLiquidityAndAmounts(
			pool,
			tickLower,
			tickUpper,
			amount0Desired,
			amount1Desired
		);

		(uint256 tokenId, , , ) = mint(
			currency0,
			currency1,
			fee,
			tickLower,
			tickUpper,
			amount0,
			amount1,
			address(dispatcher)
		);

		assertEq(UNISWAP_V3_NFT.ownerOf(tokenId), address(dispatcher));

		dispatcher.stake(key, abi.encode(abi.encode(incentive0, tokenId)));

		dispatcher.stake(key, abi.encode(abi.encode(incentive1, tokenId)));

		assertEq(UNISWAP_V3_NFT.ownerOf(tokenId), UNISWAP_V3_STAKER);

		warp(duration);

		uint256[] memory rewardsPrior = fetchBalances(rewardTokens, address(dispatcher));

		dispatcher.unstake(key, abi.encode(abi.encode(tokenId, incentive0Id, false)));

		dispatcher.unstake(key, abi.encode(abi.encode(tokenId, incentive1Id, true)));

		verifyClaim(rewardTokens, rewardsPrior);

		assertEq(UNISWAP_V3_NFT.ownerOf(tokenId), address(dispatcher));
	}

	function verifyClaim(Currency[] memory rewardTokens, uint256[] memory rewardsPrior) internal {
		uint256[] memory rewardsNew = fetchBalances(rewardTokens, address(dispatcher));

		for (uint256 i; i < rewardsPrior.length; ++i) {
			if (rewardsNew[i] != 0) {
				assertGt(rewardsNew[i], rewardsPrior[i]);
			}
		}
	}
}
