// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {UNISWAP_V3_NFT, UNISWAP_V3_STAKER} from "src/libraries/Constants.sol";
import {Incentive} from "src/libraries/Incentive.sol";
import {LiquidityAmounts} from "src/libraries/LiquidityAmounts.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {TickMath} from "src/libraries/TickMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {PoolKey, toPoolKey} from "src/types/PoolKey.sol";

abstract contract V3Utils is CommonBase, StdCheats {
	using CurrencyLibrary for Currency;
	using Incentive for Incentive.Key;
	using SafeCast for uint256;

	uint256 constant DEFAULT_REWARDS = 200000;

	address incentiveCreator = makeAddr("incentiveCreator");

	function createIncentive(
		address pool,
		Currency rewardToken,
		uint256 startTime,
		uint256 reward
	) internal returns (Incentive.Key memory incentive) {
		if (reward == 0) reward = DEFAULT_REWARDS * (10 ** rewardToken.decimals());

		deal(rewardToken.toAddress(), incentiveCreator, reward);

		vm.startPrank(incentiveCreator);

		rewardToken.approve(UNISWAP_V3_STAKER, reward);

		address refundee = incentiveCreator;

		if (startTime == 0) startTime = vm.getBlockTimestamp();

		uint256 endTime = startTime + 90 days;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x5cc5e3d900000000000000000000000000000000000000000000000000000000) // createIncentive((address,address,uint256,uint256,address),uint256)
			mstore(add(ptr, 0x04), and(rewardToken, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
			mstore(add(ptr, 0x24), and(pool, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
			mstore(add(ptr, 0x44), startTime)
			mstore(add(ptr, 0x64), endTime)
			mstore(add(ptr, 0x84), and(refundee, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
			mstore(add(ptr, 0xa4), reward)

			if iszero(call(gas(), UNISWAP_V3_STAKER, 0x00, ptr, 0xc4, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		vm.stopPrank();

		incentive = Incentive.Key({
			rewardToken: rewardToken,
			pool: pool,
			startTime: startTime.toUint40(),
			endTime: endTime.toUint40(),
			refundee: refundee
		});
	}

	function endIncentive(
		Currency rewardToken,
		address pool,
		uint256 startTime,
		uint256 endTime,
		address refundee
	) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb5ada6e400000000000000000000000000000000000000000000000000000000) // endIncentive((address,address,uint256,uint256,address))
			mstore(add(ptr, 0x04), and(rewardToken, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
			mstore(add(ptr, 0x24), and(pool, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
			mstore(add(ptr, 0x44), startTime)
			mstore(add(ptr, 0x64), endTime)
			mstore(add(ptr, 0x84), and(refundee, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))

			if iszero(call(gas(), UNISWAP_V3_STAKER, 0x00, ptr, 0xa4, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function incentives(
		bytes32 incentiveId
	)
		internal
		view
		returns (uint256 totalRewardUnclaimed, uint160 totalSecondsClaimedX128, uint96 numberOfStakes)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x6077779500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), incentiveId)

			if iszero(staticcall(gas(), UNISWAP_V3_STAKER, ptr, 0x24, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			totalRewardUnclaimed := mload(res)
			totalSecondsClaimedX128 := mload(add(res, 0x20))
			numberOfStakes := mload(add(res, 0x40))
		}
	}

	function deposits(
		uint256 tokenId
	) internal view returns (address owner, uint48 numberOfStakes, int24 tickLower, int24 tickUpper) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0xb02c43d000000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), tokenId)

			if iszero(staticcall(gas(), UNISWAP_V3_STAKER, ptr, 0x24, res, 0x80)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			owner := mload(res)
			numberOfStakes := mload(add(res, 0x20))
			tickLower := mload(add(res, 0x40))
			tickUpper := mload(add(res, 0x60))
		}
	}

	function mint(
		Currency currency0,
		Currency currency1,
		uint24 fee,
		int24 tickLower,
		int24 tickUpper,
		uint256 amount0Desired,
		uint256 amount1Desired,
		address recipient
	) internal returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
		currency0.approve(UNISWAP_V3_NFT, amount0Desired);
		currency1.approve(UNISWAP_V3_NFT, amount1Desired);

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x164)

			mstore(ptr, 0x8831645600000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(currency0, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currency1, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), and(fee, 0xffffff))
			mstore(add(ptr, 0x64), tickLower)
			mstore(add(ptr, 0x84), tickUpper)
			mstore(add(ptr, 0xa4), amount0Desired)
			mstore(add(ptr, 0xc4), amount1Desired)
			mstore(add(ptr, 0xe4), 0x00)
			mstore(add(ptr, 0x104), 0x00)
			mstore(add(ptr, 0x124), and(recipient, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x144), timestamp())

			if iszero(call(gas(), UNISWAP_V3_NFT, 0x00, ptr, 0x164, res, 0x80)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			tokenId := mload(res)
			liquidity := mload(add(res, 0x20))
			amount0 := mload(add(res, 0x40))
			amount1 := mload(add(res, 0x60))
		}
	}

	function positions(
		uint256 tokenId
	)
		internal
		view
		returns (
			uint96 nonce,
			address operator,
			Currency currency0,
			Currency currency1,
			uint24 fee,
			int24 tickLower,
			int24 tickUpper,
			uint128 liquidity,
			uint256 feeGrowthInside0LastX128,
			uint256 feeGrowthInside1LastX128,
			uint128 tokensOwed0,
			uint128 tokensOwed1
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x99fbab8800000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), tokenId)

			if iszero(staticcall(gas(), UNISWAP_V3_NFT, ptr, 0x24, res, 0x180)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			nonce := mload(res)
			operator := mload(add(res, 0x20))
			currency0 := mload(add(res, 0x40))
			currency1 := mload(add(res, 0x60))
			fee := mload(add(res, 0x80))
			tickLower := mload(add(res, 0xa0))
			tickUpper := mload(add(res, 0xc0))
			liquidity := mload(add(res, 0xe0))
			feeGrowthInside0LastX128 := mload(add(res, 0x100))
			feeGrowthInside1LastX128 := mload(add(res, 0x120))
			tokensOwed0 := mload(add(res, 0x140))
			tokensOwed1 := mload(add(res, 0x160))
		}
	}

	function slot0(
		address pool
	)
		internal
		view
		returns (
			uint160 sqrtPriceX96,
			int24 tick,
			uint16 observationIndex,
			uint16 observationCardinality,
			uint16 observationCardinalityNext,
			uint8 feeProtocol
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x04)

			mstore(ptr, 0x3850c7bd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, res, 0xc0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			sqrtPriceX96 := mload(res)
			tick := mload(add(res, 0x20))
			observationIndex := mload(add(res, 0x40))
			observationCardinality := mload(add(res, 0x60))
			observationCardinalityNext := mload(add(res, 0x80))
			feeProtocol := mload(add(res, 0xa0))
		}
	}

	function getSqrtPriceX96(address pool) internal view returns (uint160 sqrtPriceX96) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x04)

			mstore(ptr, 0x3850c7bd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, res, 0xc0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			sqrtPriceX96 := mload(res)
		}
	}

	function getTick(address pool) internal view returns (int24 tick) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x04)

			mstore(ptr, 0x3850c7bd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, res, 0xc0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			tick := mload(add(res, 0x20))
		}
	}

	function getLiquidityAndAmounts(
		address pool,
		int24 tickLower,
		int24 tickUpper,
		uint256 amount0Desired,
		uint256 amount1Desired
	) internal view returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
		uint160 sqrtRatioX96 = getSqrtPriceX96(pool);
		uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
		uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

		liquidity = LiquidityAmounts.getLiquidityForAmounts(
			sqrtRatioX96,
			sqrtRatioAX96,
			sqrtRatioBX96,
			amount0Desired,
			amount1Desired
		);

		(amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
			sqrtRatioX96,
			sqrtRatioAX96,
			sqrtRatioBX96,
			liquidity
		);
	}
}
