// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStaker} from "src/interfaces/IStaker.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {V3_FACTORY, V3_NFT, V3_STAKER} from "src/libraries/Constants.sol";
import {ERC721Utils} from "src/libraries/ERC721Utils.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Incentive} from "src/libraries/Incentive.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseModule} from "src/modules/BaseModule.sol";

/// @title V3StakerAdapter
/// @notice Provides the functionality of making calls to V3Staker for the Client

contract V3StakerAdapter is IStaker, BaseModule {
	using BytesLib for bytes;
	using CurrencyLibrary for Currency;
	using ERC721Utils for address;
	using FullMath for uint256;
	using Incentive for Incentive.Key;
	using SafeCast for uint256;
	using WadRayMath for uint256;

	error IncentiveEnded();
	error IncentiveNotExists();
	error IncentiveNotStarted();
	error TokenIdNotExists(uint256 tokenId);
	error TokenIdNotOwned(uint256 tokenId);
	error TokenIdNotStaked(uint256 tokenId);
	error TokenIdStaked(uint256 numStakes);

	struct State {
		mapping(uint256 tokenId => bytes32[]) incentiveIds;
		mapping(bytes32 incentiveId => Incentive.Key) incentives;
	}

	bytes32 private constant STORAGE_SLOT =
		bytes32(uint256(keccak256("lpm.module.adapter.staker.v3.incentives.slot")) - 1) &
			~bytes32(uint256(0xff));

	constructor(
		address _resolver,
		bytes32 _protocol,
		Currency _wrappedNative
	) BaseModule(_resolver, _protocol, _wrappedNative) {}

	function stake(bytes calldata params) external payable authorized checkDelegateCall {
		Incentive.Key calldata key;
		uint256 tokenId;

		assembly ("memory-safe") {
			key := params.offset
			tokenId := calldataload(add(params.offset, 0xa0))
		}

		// resolve the tokenId if given value is equal to 0, since it cannot be defined before mint
		// tokenId of nonfungiblePositionManager starts at 1; tokenId will never be 0
		if (tokenId == 0) {
			unchecked {
				tokenId = V3_NFT.tokenOfOwnerByIndex(address(this), V3_NFT.balanceOf(address(this)) - 1);
			}
		}

		bytes32 incentiveId = key.compute();

		(uint256 totalRewardUnclaimed, , ) = incentives(incentiveId);

		if (blockTimestamp() > key.endTime || totalRewardUnclaimed == 0) {
			revert IncentiveEnded();
		}

		State storage state = load();

		if (state.incentives[incentiveId].pool == address(0)) {
			state.incentives[incentiveId] = key;
			state.incentiveIds[tokenId].push(incentiveId);
		}

		address ownedBy = V3_NFT.ownerOf(tokenId);

		if (ownedBy != V3_STAKER) {
			if (ownedBy != address(this)) revert TokenIdNotOwned(tokenId);

			// gives the permission of NFT then transfer to the V3Staker along with incentive key;
			// tokenId will be staked when onERC721Received callback gets executed
			depositAndStake(tokenId, key.rewardToken, key.pool, key.startTime, key.endTime, key.refundee);
		} else {
			(ownedBy, , , ) = deposits(tokenId);
			if (ownedBy != address(this)) revert TokenIdNotOwned(tokenId);

			// stakes deposited tokenId; tokenId must be deposited to V3Staker already
			stakeToken(key.rewardToken, key.pool, key.startTime, key.endTime, key.refundee, tokenId);
		}
	}

	function unstake(bytes calldata params) external payable authorized checkDelegateCall {
		uint256 tokenId;
		bytes32 incentiveId;
		bool shouldWithdraw;

		assembly ("memory-safe") {
			tokenId := calldataload(params.offset)
			incentiveId := calldataload(add(params.offset, 0x20))
			shouldWithdraw := calldataload(add(params.offset, 0x40))
		}

		if (V3_NFT.ownerOf(tokenId) != V3_STAKER) revert TokenIdNotStaked(tokenId);

		State storage state = load();

		Incentive.Key memory key = state.incentives[incentiveId];

		if (key.pool == address(0)) revert IncentiveNotExists();

		bytes32[] memory cached = state.incentiveIds[tokenId];
		uint256 length = cached.length;
		uint256 lastIndex = length - 1;
		uint256 index;

		while (index < length) {
			if (cached[index] == incentiveId) break;

			unchecked {
				index = index + 1;
			}
		}

		bytes32[] storage incentiveIds = state.incentiveIds[tokenId];

		if (lastIndex != index) incentiveIds[index] = incentiveIds[lastIndex];

		incentiveIds.pop();

		delete state.incentives[incentiveId];

		unstakeToken(key.rewardToken, key.pool, key.startTime, key.endTime, key.refundee, tokenId);

		uint256 rewardsOwed = rewards(key.rewardToken);

		if (rewardsOwed != 0) claimReward(key.rewardToken, rewardsOwed);

		if (shouldWithdraw) {
			// tokenId cannot be withdrawn while staked; therefore, numberOfStakes must be equal to 0 at withdrawal
			(, uint48 numberOfStakes, , ) = deposits(tokenId);

			if (numberOfStakes != 0) revert TokenIdStaked(tokenId);

			withdrawToken(tokenId);
		}
	}

	function getRewards(bytes calldata params) external payable authorized checkDelegateCall {
		Currency rewardToken;

		assembly ("memory-safe") {
			rewardToken := calldataload(params.offset)
		}

		claimReward(rewardToken, rewards(rewardToken));
	}

	function getPendingRewards(
		bytes calldata params
	) external view returns (PendingReward[] memory pendingRewards) {
		uint256 tokenId;

		assembly ("memory-safe") {
			tokenId := calldataload(params.offset)
		}

		State storage state = load();

		bytes32[] memory cached = state.incentiveIds[tokenId];
		uint256 length = cached.length;
		uint256 i;

		pendingRewards = new PendingReward[](length);

		while (i < length) {
			Currency rewardToken = state.incentives[cached[i]].rewardToken;

			pendingRewards[i] = PendingReward(rewardToken, rewards(rewardToken));

			unchecked {
				i = i + 1;
			}
		}
	}

	function getRewardsList(bytes calldata params) external view returns (Currency[] memory rewardAssets) {
		uint256 tokenId;

		assembly ("memory-safe") {
			tokenId := calldataload(params.offset)
		}

		State storage state = load();

		bytes32[] memory cached = state.incentiveIds[tokenId];
		uint256 length = cached.length;
		uint256 i;

		rewardAssets = new Currency[](length);

		while (i < length) {
			rewardAssets[i] = state.incentives[cached[i]].rewardToken;

			unchecked {
				i = i + 1;
			}
		}
	}

	function depositAndStake(
		uint256 tokenId,
		Currency rewardToken,
		address pool,
		uint256 startTime,
		uint256 endTime,
		address refundee
	) internal {
		assembly ("memory-safe") {
			function execute(t, p, s) {
				if iszero(call(gas(), t, 0x00, p, s, 0x00, 0x00)) {
					returndatacopy(p, 0x00, returndatasize())
					revert(p, returndatasize())
				}
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000) // approve(address,uint256)
			mstore(add(ptr, 0x04), and(V3_STAKER, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), tokenId)

			execute(V3_NFT, ptr, 0x44)

			mstore(ptr, 0xb88d4fde00000000000000000000000000000000000000000000000000000000) // safeTransferFrom(address,address,uint256,bytes)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(V3_STAKER, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), tokenId)
			mstore(add(ptr, 0x64), 0x80)
			mstore(add(ptr, 0x84), 0xa0)
			mstore(add(ptr, 0xa4), and(rewardToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0xc4), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0xe4), startTime)
			mstore(add(ptr, 0x104), endTime)
			mstore(add(ptr, 0x124), and(refundee, 0xffffffffffffffffffffffffffffffffffffffff))

			execute(V3_NFT, ptr, 0x144)
		}
	}

	function stakeToken(
		Currency rewardToken,
		address pool,
		uint256 startTime,
		uint256 endTime,
		address refundee,
		uint256 tokenId
	) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf2d2909b00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(rewardToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), startTime)
			mstore(add(ptr, 0x64), endTime)
			mstore(add(ptr, 0x84), and(refundee, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0xa4), tokenId)

			if iszero(call(gas(), V3_STAKER, 0x00, ptr, 0xc4, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unstakeToken(
		Currency rewardToken,
		address pool,
		uint256 startTime,
		uint256 endTime,
		address refundee,
		uint256 tokenId
	) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf549ab4200000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(rewardToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), startTime)
			mstore(add(ptr, 0x64), endTime)
			mstore(add(ptr, 0x84), and(refundee, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0xa4), tokenId)

			if iszero(call(gas(), V3_STAKER, 0x00, ptr, 0xc4, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function withdrawToken(uint256 tokenId) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x3c423f0b00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), tokenId)
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), 0x60)
			mstore(add(ptr, 0x64), 0x00)

			if iszero(call(gas(), V3_STAKER, 0x00, ptr, 0x84, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function claimReward(Currency rewardToken, uint256 amountRequested) internal returns (uint256 reward) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x2f2d783d00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(rewardToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), amountRequested)

			if iszero(call(gas(), V3_STAKER, 0x00, ptr, 0x64, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			reward := mload(0x00)
		}
	}

	function getRewardInfo(
		Currency rewardToken,
		address pool,
		uint256 startTime,
		uint256 endTime,
		address refundee,
		uint256 tokenId
	) internal view returns (uint256 reward, uint160 secondsInsideX128) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0xc4)

			mstore(ptr, 0xd953186e00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(rewardToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), startTime)
			mstore(add(ptr, 0x64), endTime)
			mstore(add(ptr, 0x84), and(refundee, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0xa4), tokenId)

			if iszero(staticcall(gas(), V3_STAKER, ptr, 0xc4, 0x00, 0x40)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			reward := mload(0x00)
			secondsInsideX128 := mload(0x20)
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

			if iszero(staticcall(gas(), V3_STAKER, ptr, 0x24, res, 0x80)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			owner := mload(res)
			numberOfStakes := mload(add(res, 0x20))
			tickLower := mload(add(res, 0x40))
			tickUpper := mload(add(res, 0x60))
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

			if iszero(staticcall(gas(), V3_STAKER, ptr, 0x24, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			totalRewardUnclaimed := mload(res)
			totalSecondsClaimedX128 := mload(add(res, 0x20))
			numberOfStakes := mload(add(res, 0x40))
		}
	}

	function rewards(Currency rewardToken) internal view returns (uint256 rewardsOwed) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xe70b9e2700000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(rewardToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), V3_STAKER, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			rewardsOwed := mload(0x00)
		}
	}

	function stakes(
		uint256 tokenId,
		bytes32 incentiveId
	) internal view returns (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xc36c1ea500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), tokenId)
			mstore(add(ptr, 0x24), incentiveId)

			if iszero(staticcall(gas(), V3_STAKER, ptr, 0x44, 0x00, 0x40)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			secondsPerLiquidityInsideInitialX128 := mload(0x00)
			liquidity := mload(0x20)
		}
	}

	function load() internal pure returns (State storage s) {
		bytes32 slot = STORAGE_SLOT;

		assembly ("memory-safe") {
			s.slot := slot
		}
	}
}
