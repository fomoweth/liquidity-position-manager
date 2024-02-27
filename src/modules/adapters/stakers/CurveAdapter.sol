// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStaker} from "src/interfaces/IStaker.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {CRV_MINTER, GAUGE_FACTORY} from "src/libraries/Constants.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseModule} from "src/modules/BaseModule.sol";

/// @title CurveAdapter
/// @notice Provides the functionality of making calls to Curve-LiquidityGauge contracts for the Client

contract CurveAdapter is IStaker, BaseModule {
	using CurrencyLibrary for Currency;
	using WadRayMath for uint256;

	error InvalidLiquidityGauge();

	address internal immutable MINTER;
	Currency internal immutable CRV;

	uint256 internal constant MAX_REWARDS = 8;

	constructor(
		address _resolver,
		bytes32 _protocol,
		Currency _wrappedNative,
		Currency _crv
	) BaseModule(_resolver, _protocol, _wrappedNative) {
		MINTER = setMinter(isEthereum());
		CRV = _crv;
	}

	function stake(bytes calldata params) external payable authorized checkDelegateCall {
		Currency token;
		Currency gauge;
		uint256 amount;

		assembly ("memory-safe") {
			token := calldataload(params.offset)
			gauge := calldataload(add(params.offset, 0x20))
			amount := calldataload(add(params.offset, 0x40))
		}

		uint256 liquidity = token.balanceOfSelf();
		if (amount == 0 || amount > liquidity) amount = liquidity;

		approveIfNeeded(token, gauge.toAddress(), amount);

		deposit(gauge, amount);
	}

	function unstake(bytes calldata params) external payable authorized checkDelegateCall {
		Currency gauge;
		uint256 amount;
		bool shouldMint;
		bool shouldClaim;

		assembly ("memory-safe") {
			gauge := calldataload(params.offset)
			amount := calldataload(add(params.offset, 0x20))
			shouldMint := calldataload(add(params.offset, 0x40))
			shouldClaim := calldataload(add(params.offset, 0x60))
		}

		uint256 staked = gauge.balanceOfSelf();
		if (amount == 0 || amount > staked) amount = staked;

		withdraw(gauge, amount);
		claimCrv(MINTER, gauge);

		if (getRewardAssets(gauge).length != 1) claimRewards(gauge);
	}

	function getRewards(bytes calldata params) external payable authorized checkDelegateCall {
		Currency gauge;

		assembly ("memory-safe") {
			gauge := calldataload(params.offset)
		}

		uint256 length = getRewardAssets(gauge).length;
		if (length == 0) revert InvalidLiquidityGauge();

		claimCrv(MINTER, gauge);
		if (length != 1) claimRewards(gauge);
	}

	function getPendingRewards(
		bytes calldata params
	) external view returns (PendingReward[] memory pendingRewards) {
		//
	}

	function getRewardsList(bytes calldata params) external view returns (Currency[] memory) {
		Currency gauge;

		assembly ("memory-safe") {
			gauge := calldataload(params.offset)
		}

		return getRewardAssets(gauge);
	}

	function deposit(Currency gauge, uint256 amount) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb6b55f2500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), gauge, 0x00, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function withdraw(Currency gauge, uint256 amount) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), gauge, 0x00, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function claimCrv(address minter, Currency gauge) internal {
		assembly ("memory-safe") {
			function execute(t, p) {
				if iszero(call(gas(), t, 0x00, p, 0x24, 0x00, 0x00)) {
					returndatacopy(p, 0x00, returndatasize())
					revert(p, returndatasize())
				}
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x6a62784200000000000000000000000000000000000000000000000000000000) // mint(address)
			mstore(add(ptr, 0x04), and(gauge, 0xffffffffffffffffffffffffffffffffffffffff))

			execute(minter, ptr)

			mstore(ptr, 0x4b82009300000000000000000000000000000000000000000000000000000000) // user_checkpoint(address)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			execute(gauge, ptr)
		}
	}

	function claimRewards(Currency gauge) internal returns (bool success) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xe6f1daf200000000000000000000000000000000000000000000000000000000) // claim_rewards()

			success := call(gas(), gauge, 0x00, ptr, 0x04, 0x00, 0x00)
		}
	}

	function getRewardAssets(Currency gauge) internal view returns (Currency[] memory rewardAssets) {
		uint256 length = rewardCount(gauge);
		uint256 count = 1;
		uint256 i;

		rewardAssets = new Currency[](length);
		rewardAssets[0] = CRV;

		Currency rewardToken = rewardedToken(gauge);

		if (!rewardToken.isZero()) {
			rewardAssets[1] = rewardToken;

			unchecked {
				count = count + 1;
			}
		} else {
			while (i < length) {
				rewardToken = rewardTokens(gauge, i);

				if (rewardToken.isZero()) break;

				if (rewardToken != CRV) {
					rewardAssets[count] = rewardToken;

					unchecked {
						count = count + 1;
					}
				}

				unchecked {
					i = i + 1;
				}
			}
		}

		assembly ("memory-safe") {
			mstore(rewardAssets, count)
		}
	}

	function rewardContract(Currency gauge) internal view returns (Currency rewarder) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xbf88a6ff00000000000000000000000000000000000000000000000000000000) // reward_contract()

			if staticcall(gas(), gauge, ptr, 0x04, 0x00, 0x20) {
				rewarder := mload(0x00)
			}
		}
	}

	function rewardedToken(Currency gauge) internal view returns (Currency rewardToken) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x16fa50b100000000000000000000000000000000000000000000000000000000)

			if staticcall(gas(), gauge, ptr, 0x04, 0x00, 0x20) {
				rewardToken := mload(0x00)
			}
		}
	}

	function rewardTokens(Currency gauge, uint256 offset) internal view returns (Currency rewardToken) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x54c49fe900000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), offset)

			if staticcall(gas(), gauge, ptr, 0x24, 0x00, 0x20) {
				rewardToken := mload(0x00)
			}
		}
	}

	function rewardCount(Currency gauge) internal view returns (uint256 count) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb6b55f2500000000000000000000000000000000000000000000000000000000)

			switch staticcall(gas(), gauge, ptr, 0x04, 0x00, 0x20)
			case 0x00 {
				count := MAX_REWARDS
			}
			default {
				count := mload(0x00)
			}
		}
	}

	function setMinter(bool isEthereum) internal pure returns (address) {
		return isEthereum ? CRV_MINTER : GAUGE_FACTORY;
	}
}
