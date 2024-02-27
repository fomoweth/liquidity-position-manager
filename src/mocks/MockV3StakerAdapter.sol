// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UNISWAP_V3_NFT} from "src/libraries/Constants.sol";
import {Incentive} from "src/libraries/Incentive.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {PoolKey, toPoolKey} from "src/types/PoolKey.sol";
import {V3StakerAdapter} from "src/modules/adapters/stakers/V3StakerAdapter.sol";

contract MockV3StakerAdapter is V3StakerAdapter {
	using CurrencyLibrary for Currency;

	constructor(
		address _resolver,
		bytes32 _protocol,
		Currency _wrappedNative
	) V3StakerAdapter(_resolver, _protocol, _wrappedNative) {}

	function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
		return this.onERC721Received.selector;
	}

	function mint(
		Currency currency0,
		Currency currency1,
		uint24 fee,
		int24 tickLower,
		int24 tickUpper,
		uint256 amount0Desired,
		uint256 amount1Desired
	) public payable returns (uint256 tokenId) {
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
			mstore(add(ptr, 0x124), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x144), timestamp())

			if iszero(call(gas(), UNISWAP_V3_NFT, 0x00, ptr, 0x164, res, 0x80)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			tokenId := mload(res)
		}
	}

	function getIncentive(bytes32 incentiveId) public view returns (Incentive.Key memory) {
		return load().incentives[incentiveId];
	}

	function getIncentiveIndex(uint256 tokenId, bytes32 incentiveId) public view returns (uint256 index) {
		bytes32[] memory cached = load().incentiveIds[tokenId];
		uint256 length = cached.length;

		while (index < length) {
			if (cached[index] == incentiveId) break;

			unchecked {
				index = index + 1;
			}
		}
	}

	function getIncentivesLength(uint256 tokenId) public view returns (uint256) {
		return load().incentiveIds[tokenId].length;
	}

	function getIncentiveId(uint256 tokenId, uint256 index) public view returns (bytes32) {
		return load().incentiveIds[tokenId][index];
	}

	function getPendingReward(Currency rewardToken) public view returns (uint256) {
		return rewards(rewardToken);
	}

	function isAuthorized(address) internal view virtual override returns (bool) {
		return true;
	}

	function _checkDelegateCall() internal view virtual override {}

	function _noDelegateCall() internal view virtual override {}

	receive() external payable {}
}
