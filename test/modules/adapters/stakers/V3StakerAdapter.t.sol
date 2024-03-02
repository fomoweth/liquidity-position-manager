// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStaker} from "src/interfaces/IStaker.sol";
import {UNISWAP_V3_NFT, UNISWAP_V3_STAKER} from "src/libraries/Constants.sol";
import {ERC721Utils} from "src/libraries/ERC721Utils.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Incentive} from "src/libraries/Incentive.sol";
import {LiquidityAmounts} from "src/libraries/LiquidityAmounts.sol";
import {TickMath} from "src/libraries/TickMath.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {PoolKey, toPoolKey} from "src/types/PoolKey.sol";
import {MockV3StakerAdapter} from "src/mocks/MockV3StakerAdapter.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

// forge test -vvv --match-path test/modules/adapters/stakers/V3StakerAdapter.t.sol

contract V3StakerAdapterTest is BaseTest {
	using CurrencyLibrary for Currency;
	using ERC721Utils for address;
	using Incentive for Incentive.Key;

	MockV3StakerAdapter adapter;

	function setUp() public virtual override {
		_setUp(ETHEREUM_CHAIN_ID, true);

		vm.label(
			address(adapter = new MockV3StakerAdapter(address(resolver), UNI_V3_ID, WRAPPED_NATIVE)),
			"MockV3StakerAdapter"
		);
	}

	function test_stakingActions_DAI_WETH_500() public {
		simulate(DAI, WETH, 500);
	}

	function test_stakingActions_DAI_WETH_3000() public {
		simulate(DAI, WETH, 3000);
	}

	function test_stakingActions_DAI_WETH_10000() public {
		simulate(DAI, WETH, 10000);
	}

	function simulate(Currency currency0, Currency currency1, uint24 fee) internal {
		uint256 ethAmount = 10 ether;
		uint256 duration = 30;

		PoolKey memory poolKey = toPoolKey(currency0, currency1, fee);

		address pool = poolKey.compute();

		Currency[] memory rewardAssets = new Currency[](2);
		rewardAssets[0] = currency0;
		rewardAssets[1] = currency1;

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

		deal(currency0, address(adapter), amount0Desired);
		deal(currency1, address(adapter), amount1Desired);

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

		uint256 tokenId = adapter.mint(currency0, currency1, fee, tickLower, tickUpper, amount0, amount1);

		assertEq(UNISWAP_V3_NFT.ownerOf(tokenId), address(adapter));

		adapter.stake(abi.encode(incentive0, tokenId));

		assertEq(adapter.getIncentivesLength(tokenId), 1);

		adapter.stake(abi.encode(incentive1, tokenId));

		assertEq(adapter.getIncentivesLength(tokenId), 2);

		assertEq(UNISWAP_V3_NFT.ownerOf(tokenId), UNISWAP_V3_STAKER);

		assertEq(
			keccak256(abi.encode(adapter.getRewardsList(abi.encode(tokenId)))),
			keccak256(abi.encode(rewardAssets))
		);

		uint256 index0 = adapter.getIncentiveIndex(tokenId, incentive0Id);
		uint256 index1 = adapter.getIncentiveIndex(tokenId, incentive1Id);

		assertEq(index0, 0);
		assertEq(index1, 1);

		assertEq(adapter.getIncentiveId(tokenId, index0), incentive0Id);
		assertEq(adapter.getIncentiveId(tokenId, index1), incentive1Id);

		assertEq(
			keccak256(abi.encode(adapter.getIncentive(incentive0Id))),
			keccak256(abi.encode(incentive0))
		);
		assertEq(
			keccak256(abi.encode(adapter.getIncentive(incentive1Id))),
			keccak256(abi.encode(incentive1))
		);

		warp(duration);

		uint256 rewards0Prior = currency0.balanceOf(address(adapter));
		uint256 rewards1Prior = currency1.balanceOf(address(adapter));

		adapter.unstake(abi.encode(tokenId, incentive0Id, false));

		assertEq(adapter.getIncentivesLength(tokenId), 1);

		adapter.unstake(abi.encode(tokenId, incentive1Id, true));

		assertEq(adapter.getIncentivesLength(tokenId), 0);

		uint256 rewards0New = currency0.balanceOf(address(adapter));
		uint256 rewards1New = currency1.balanceOf(address(adapter));

		assertEq(UNISWAP_V3_NFT.ownerOf(tokenId), address(adapter));
		assertGt(rewards0New, rewards0Prior);
		assertGt(rewards1New, rewards1Prior);
	}
}
