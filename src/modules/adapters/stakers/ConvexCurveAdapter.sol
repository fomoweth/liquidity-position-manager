// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {IStaker} from "src/interfaces/IStaker.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {BOOSTER} from "src/libraries/Constants.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseModule} from "src/modules/BaseModule.sol";

/// @title ConvexCurveAdapter
/// @notice Provides the functionality of making calls to Convex-Curve staking contracts for the Client

contract ConvexCurveAdapter is IStaker, BaseModule {
	using BytesLib for bytes;
	using CurrencyLibrary for Currency;
	using FullMath for uint256;
	using WadRayMath for uint256;

	function(uint256, uint256) internal immutable depositAndStake;

	function(Currency, uint256) internal immutable unstakeAndWithdraw;

	function(Currency) internal immutable getReward;

	function(Currency, address) internal view returns (PendingReward[] memory)
		internal immutable getPendingReward;

	function(Currency, address) internal view returns (Currency[] memory) internal immutable getRewardAssets;

	function(uint256) internal view returns (Currency, Currency, Currency, Currency, address, bool)
		internal immutable poolInfo;

	Currency internal immutable CRV;
	Currency internal immutable CVX;

	constructor(
		address _resolver,
		bytes32 _protocol,
		Currency _wrappedNative,
		Currency _crv,
		Currency _cvx
	) BaseModule(_resolver, _protocol, _wrappedNative) {
		CRV = _crv;
		CVX = _cvx;

		(depositAndStake, unstakeAndWithdraw, getReward, getPendingReward, getRewardAssets, poolInfo) = setup(
			isEthereum()
		);
	}

	function stake(bytes calldata params) external payable authorized checkDelegateCall {
		uint256 pid;
		uint256 amount;

		assembly ("memory-safe") {
			pid := calldataload(params.offset)
			amount := calldataload(add(params.offset, 0x20))
		}

		(, , Currency lpToken, , , bool shutdown) = poolInfo(pid);

		if (shutdown) revert Errors.NotActive();

		uint256 approval = lpToken.balanceOfSelf();

		if (amount < approval) approval = amount;
		else amount = MAX_UINT256;

		lpToken.approve(BOOSTER, approval);

		depositAndStake(pid, amount);

		lpToken.approve(BOOSTER, 0);
	}

	function unstake(bytes calldata params) external payable authorized checkDelegateCall {
		uint256 pid;
		uint256 amount;

		assembly ("memory-safe") {
			pid := calldataload(params.offset)
			amount := calldataload(add(params.offset, 0x20))
		}

		(Currency rewardPool, , , , , ) = poolInfo(pid);

		if (amount == 0 || amount > rewardPool.balanceOfSelf()) amount = MAX_UINT256;

		unstakeAndWithdraw(rewardPool, amount);
	}

	function getRewards(bytes calldata params) external payable authorized checkDelegateCall {
		uint256 pid;

		assembly ("memory-safe") {
			pid := calldataload(params.offset)
		}

		(Currency rewardPool, , , , , ) = poolInfo(pid);

		getReward(rewardPool);
	}

	function getPendingRewards(
		bytes calldata params
	) external view returns (PendingReward[] memory pendingRewards) {
		uint256 pid;

		assembly ("memory-safe") {
			pid := calldataload(params.offset)
		}

		(Currency rewardPool, , , , address stash, ) = poolInfo(pid);

		return getPendingReward(rewardPool, stash);
	}

	function getRewardsList(bytes calldata params) external view returns (Currency[] memory rewardAssets) {
		uint256 pid;

		assembly ("memory-safe") {
			pid := calldataload(params.offset)
		}

		(Currency rewardPool, , , , address stash, ) = poolInfo(pid);

		return getRewardAssets(rewardPool, stash);
	}

	function depositAndStakeL1(uint256 pid, uint256 amount) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch eq(amount, MAX_UINT256)
			case 0x00 {
				mstore(ptr, 0x43a0d06600000000000000000000000000000000000000000000000000000000) // deposit(uint256,uint256,bool)
				mstore(add(ptr, 0x04), pid)
				mstore(add(ptr, 0x24), amount)
				mstore(add(ptr, 0x44), and(0x01, 0xff))

				if iszero(call(gas(), BOOSTER, 0x00, ptr, 0x64, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				mstore(ptr, 0x60759fce00000000000000000000000000000000000000000000000000000000) // depositAll(uint256,bool)
				mstore(add(ptr, 0x04), pid)
				mstore(add(ptr, 0x24), and(0x01, 0xff))

				if iszero(call(gas(), BOOSTER, 0x00, ptr, 0x44, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function depositAndStakeL2(uint256 pid, uint256 amount) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch eq(amount, MAX_UINT256)
			case 0x00 {
				mstore(ptr, 0xe2bbb15800000000000000000000000000000000000000000000000000000000) // deposit(uint256,uint256)
				mstore(add(ptr, 0x04), pid)
				mstore(add(ptr, 0x24), amount)

				if iszero(call(gas(), BOOSTER, 0x00, ptr, 0x44, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				mstore(ptr, 0xc6f678bd00000000000000000000000000000000000000000000000000000000) // depositAll(uint256)
				mstore(add(ptr, 0x04), pid)

				if iszero(call(gas(), BOOSTER, 0x00, ptr, 0x24, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function unstakeAndWithdrawL1(Currency rewardPool, uint256 amount) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch eq(amount, MAX_UINT256)
			case 0x00 {
				mstore(ptr, 0x49f039a200000000000000000000000000000000000000000000000000000000) // withdrawAndUnwrap(uint256,bool)
				mstore(add(ptr, 0x04), amount)
				mstore(add(ptr, 0x24), and(0x01, 0xff))

				if iszero(call(gas(), rewardPool, 0x00, ptr, 0x44, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				mstore(ptr, 0xc32e720200000000000000000000000000000000000000000000000000000000) // withdrawAllAndUnwrap(bool)
				mstore(add(ptr, 0x04), and(0x01, 0xff))

				if iszero(call(gas(), rewardPool, 0x00, ptr, 0x24, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function unstakeAndWithdrawL2(Currency rewardPool, uint256 amount) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch eq(amount, MAX_UINT256)
			case 0x00 {
				mstore(ptr, 0x38d0743600000000000000000000000000000000000000000000000000000000) // withdraw(uint256,bool)
				mstore(add(ptr, 0x04), amount)
				mstore(add(ptr, 0x24), and(0x01, 0xff))

				if iszero(call(gas(), rewardPool, 0x00, ptr, 0x44, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				mstore(ptr, 0x1c1c6fe500000000000000000000000000000000000000000000000000000000) // withdrawAll(bool)
				mstore(add(ptr, 0x04), and(0x01, 0xff))

				if iszero(call(gas(), rewardPool, 0x00, ptr, 0x24, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function getRewardL1(Currency rewardPool) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x7050ccd900000000000000000000000000000000000000000000000000000000) // getReward(address,bool)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(0x01, 0xff))

			if iszero(call(gas(), rewardPool, 0x00, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getRewardL2(Currency rewardPool) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xc00007b000000000000000000000000000000000000000000000000000000000) // getReward(address,address)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), rewardPool, 0x00, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getPendingRewardsL1(
		Currency rewardPool,
		address stash
	) internal view returns (PendingReward[] memory pendingRewards) {
		uint256 offset = 2;
		uint256 length = offset;
		uint256 extraLength = extraRewardsLength(rewardPool);

		unchecked {
			length += extraLength;
		}

		pendingRewards = new PendingReward[](length);

		uint256 crvRewards = earned(rewardPool);
		uint256 cvxRewards = computeCVXRewards(crvRewards);

		pendingRewards[0] = PendingReward(CRV, crvRewards);
		pendingRewards[1] = PendingReward(CVX, cvxRewards);

		if (extraLength != 0) {
			bool useV3Stash = isV3Stash(stash);
			uint256 i;

			while (i < extraLength) {
				Currency extraRewardPool = extraRewards(rewardPool, i);
				Currency rewardAsset = !useV3Stash ? rewardToken(extraRewardPool) : tokenList(stash, i);

				if (rewardAsset != CRV && rewardAsset != CVX) {
					pendingRewards[offset] = PendingReward(rewardAsset, earned(extraRewardPool));

					unchecked {
						offset = offset + 1;
					}
				}

				unchecked {
					i = i + 1;
				}
			}
		}

		assembly ("memory-safe") {
			if iszero(eq(offset, length)) {
				mstore(pendingRewards, offset)
			}
		}
	}

	function getPendingRewardsL2(
		Currency rewardPool,
		address
	) internal view returns (PendingReward[] memory pendingRewards) {
		uint256 totalSupply = rewardPool.totalSupply();
		uint256 staked = rewardPool.balanceOfSelf();

		uint256 length = rewardLength(rewardPool);
		uint256 i;

		pendingRewards = new PendingReward[](length);

		while (i < length) {
			(pendingRewards[i].asset, pendingRewards[i].amount) = computeRewardIntegral(
				rewardPool,
				staked,
				totalSupply,
				i
			);

			unchecked {
				i = i + 1;
			}
		}
	}

	function getRewardAssetsL1(
		Currency rewardPool,
		address stash
	) internal view returns (Currency[] memory rewardAssets) {
		uint256 offset = 2;
		uint256 length = offset;
		uint256 extraLength = extraRewardsLength(rewardPool);

		unchecked {
			length += extraLength;
		}

		rewardAssets = new Currency[](length);
		rewardAssets[0] = CRV;
		rewardAssets[1] = CVX;

		if (extraLength != 0) {
			bool useV3Stash = isV3Stash(stash);
			uint256 i;

			while (i < extraLength) {
				Currency rewardAsset = !useV3Stash
					? rewardToken(extraRewards(rewardPool, i))
					: tokenList(stash, i);

				if (rewardAsset != CRV && rewardAsset != CVX) {
					rewardAssets[offset] = rewardAsset;

					unchecked {
						offset = offset + 1;
					}
				}

				unchecked {
					i = i + 1;
				}
			}
		}

		assembly ("memory-safe") {
			if iszero(eq(offset, length)) {
				mstore(rewardAssets, offset)
			}
		}
	}

	function getRewardAssetsL2(
		Currency rewardPool,
		address
	) internal view returns (Currency[] memory rewardAssets) {
		uint256 length = rewardLength(rewardPool);
		uint256 i;

		rewardAssets = new Currency[](length);

		while (i < length) {
			(rewardAssets[i], , ) = rewards(rewardPool, i);

			unchecked {
				i = i + 1;
			}
		}
	}

	function poolInfoL1(
		uint256 pid
	)
		internal
		view
		returns (
			Currency rewardPool,
			Currency token,
			Currency lpToken,
			Currency gauge,
			address stash,
			bool shutdown
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x1526fe2700000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), pid)

			if iszero(staticcall(gas(), BOOSTER, ptr, 0x24, res, 0xc0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			lpToken := mload(res)
			token := mload(add(res, 0x20))
			gauge := mload(add(res, 0x40))
			rewardPool := mload(add(res, 0x60))
			stash := mload(add(res, 0x80))
			shutdown := mload(add(res, 0xa0))
		}
	}

	function poolInfoL2(
		uint256 pid
	)
		internal
		view
		returns (
			Currency rewardPool,
			Currency token,
			Currency lpToken,
			Currency gauge,
			address stash,
			bool shutdown
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x1526fe2700000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), pid)

			if iszero(staticcall(gas(), BOOSTER, ptr, 0x24, res, 0xa0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			lpToken := mload(res)
			gauge := mload(add(res, 0x20))
			rewardPool := mload(add(res, 0x40))
			token := rewardPool
			stash := 0x00
			shutdown := mload(add(res, 0x60))
		}
	}

	function computeCVXRewards(uint256 crvRewards) internal view returns (uint256 cvxRewards) {
		Currency cvx = CVX;

		uint256 totalSupply = cvx.totalSupply();

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x20)

			mstore(ptr, 0xd5abeb0100000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), 0x1f96e76f00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x08), 0xaa74e62200000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cvx, ptr, 0x04, res, 0x20)) {
				revert(ptr, 0x04)
			}

			if iszero(staticcall(gas(), cvx, add(ptr, 0x04), 0x04, add(res, 0x20), 0x20)) {
				revert(add(ptr, 0x04), 0x04)
			}

			if iszero(staticcall(gas(), cvx, add(ptr, 0x08), 0x04, add(res, 0x40), 0x20)) {
				revert(add(ptr, 0x08), 0x04)
			}

			let maxSupply := mload(res)
			let totalCliffs := mload(add(res, 0x20))
			let reductionPerCliff := mload(add(res, 0x40))
			let cliff := div(totalSupply, reductionPerCliff)

			if gt(totalCliffs, cliff) {
				cvxRewards := div(mul(crvRewards, sub(totalCliffs, cliff)), totalCliffs)

				let remainingSupply := sub(maxSupply, totalSupply)

				if gt(cvxRewards, remainingSupply) {
					cvxRewards := remainingSupply
				}
			}
		}
	}

	function computeRewardIntegral(
		Currency rewardPool,
		uint256 staked,
		uint256 totalSupply,
		uint256 offset
	) internal view returns (Currency rewardAsset, uint256 claimable) {
		uint256 rewardIntegral;
		uint256 rewardRemaining;

		(rewardAsset, rewardIntegral, rewardRemaining) = rewards(rewardPool, offset);

		if (!rewardAsset.isZero() && rewardIntegral != 0 && rewardRemaining != 0) {
			uint256 poolBalance = rewardAsset.balanceOf(rewardPool.toAddress());

			assembly ("memory-safe") {
				if iszero(offset) {
					let ptr := mload(0x40)

					mstore(ptr, 0x19d695e000000000000000000000000000000000000000000000000000000000) // calculatePlatformFees(uint256)
					mstore(add(ptr, 0x04), sub(poolBalance, rewardRemaining))

					if iszero(staticcall(gas(), BOOSTER, ptr, 0x24, 0x00, 0x20)) {
						returndatacopy(ptr, 0x00, returndatasize())
						revert(ptr, returndatasize())
					}

					let fees := mload(0x00)

					if gt(fees, 0x00) {
						poolBalance := sub(poolBalance, fees)
					}
				}
			}

			if (totalSupply != 0 && poolBalance > rewardRemaining) {
				rewardIntegral += (poolBalance - rewardRemaining).mulDiv(1e20, totalSupply);
			}

			claimable =
				claimableReward(rewardPool, rewardAsset) +
				FullMath.mulDiv(staked, (rewardIntegral - rewardIntegralFor(rewardPool, rewardAsset)), 1e20);
		}
	}

	function earned(Currency rewardPool) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x008cc26200000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), rewardPool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function rewards(
		Currency rewardPool,
		uint256 offset
	) internal view returns (Currency rewardAsset, uint256 rewardIntegral, uint256 rewardRemaining) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0xf301af4200000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), offset)

			if iszero(staticcall(gas(), rewardPool, ptr, 0x24, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			rewardAsset := mload(res)
			rewardIntegral := mload(add(res, 0x20))
			rewardRemaining := mload(add(res, 0x40))
		}
	}

	function claimableReward(
		Currency rewardPool,
		Currency rewardAsset
	) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x33fd6f7400000000000000000000000000000000000000000000000000000000) // claimable_reward(address,address)
			mstore(add(ptr, 0x04), and(rewardAsset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), rewardPool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function rewardIntegralFor(
		Currency rewardPool,
		Currency rewardAsset
	) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf05cc05800000000000000000000000000000000000000000000000000000000) // reward_integral_for(address,address)
			mstore(add(ptr, 0x04), and(rewardAsset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), rewardPool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function extraRewards(Currency rewardPool, uint256 offset) internal view returns (Currency reward) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x40c3544600000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), offset)

			if iszero(staticcall(gas(), rewardPool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			reward := mload(0x00)
		}
	}

	function extraRewardsLength(Currency rewardPool) internal view returns (uint256 length) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd55a23f400000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), rewardPool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			length := mload(0x00)
		}
	}

	function rewardToken(Currency rewardPool) internal view returns (Currency rewardAsset) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf7c618c100000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), rewardPool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			rewardAsset := mload(0x00)
		}
	}

	function rewardLength(Currency rewardPool) internal view returns (uint256 length) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb95c574600000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), rewardPool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			length := mload(0x00)
		}
	}

	function tokenList(address stash, uint256 offset) internal view returns (Currency asset) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x9ead722200000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), offset)

			if iszero(staticcall(gas(), stash, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			asset := mload(0x00)
		}
	}

	function isV3Stash(address stash) internal view returns (bool res) {
		if (stash != address(0)) {
			assembly ("memory-safe") {
				let ptr := mload(0x40)

				mstore(ptr, 0x9ead722200000000000000000000000000000000000000000000000000000000) // tokenList(uint256)
				mstore(add(ptr, 0x04), 0x00)

				res := staticcall(gas(), stash, ptr, 0x24, 0x00, 0x20)
			}
		}
	}

	function setup(
		bool isEthereum
	)
		internal
		pure
		returns (
			function(uint256, uint256) internal,
			function(Currency, uint256) internal,
			function(Currency) internal,
			function(Currency, address) internal view returns (PendingReward[] memory),
			function(Currency, address) internal view returns (Currency[] memory),
			function(uint256) internal view returns (Currency, Currency, Currency, Currency, address, bool)
		)
	{
		return
			isEthereum
				? (
					depositAndStakeL1,
					unstakeAndWithdrawL1,
					getRewardL1,
					getPendingRewardsL1,
					getRewardAssetsL1,
					poolInfoL1
				)
				: (
					depositAndStakeL2,
					unstakeAndWithdrawL2,
					getRewardL2,
					getPendingRewardsL2,
					getRewardAssetsL2,
					poolInfoL2
				);
	}
}
