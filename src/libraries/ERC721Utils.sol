// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ERC721Utils
/// @notice Helper library for ERC721

library ERC721Utils {
	function safeTransferFrom(address nft, address from, address to, uint256 tokenId) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x42842e0e00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(from, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), tokenId)

			if iszero(call(gas(), nft, 0x00, ptr, 0x64, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function safeTransferFrom(
		address nft,
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb88d4fde00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(from, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), tokenId)
			mstore(add(ptr, 0x64), 0x80)
			mstore(add(ptr, 0x84), mload(data))

			let offset := add(ptr, 0xa4)
			let guard := add(offset, mload(data))

			for {
				let i := add(data, 0x20)
			} lt(offset, guard) {
				offset := add(offset, 0x20)
				i := add(i, 0x20)
			} {
				mstore(offset, mload(i))
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			if iszero(call(gas(), nft, 0x00, ptr, add(0xa4, mul(0x20, mload(data))), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getTokenIds(address nft, address account) internal view returns (uint256[] memory tokenIds) {
		uint256 length = balanceOf(nft, account);
		uint256 i;

		tokenIds = new uint256[](length);

		while (i < length) {
			tokenIds[i] = tokenOfOwnerByIndex(nft, account, i);

			unchecked {
				i = i + 1;
			}
		}
	}

	function tokenOfOwnerByIndex(
		address nft,
		address account,
		uint256 index
	) internal view returns (uint256 tokenId) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x2f745c5900000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), index)

			if iszero(staticcall(gas(), nft, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			tokenId := mload(0x00)
		}
	}

	function balanceOf(address nft, address account) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), nft, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function ownerOf(address nft, uint256 tokenId) internal view returns (address owner) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6352211e00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), tokenId)

			if iszero(staticcall(gas(), nft, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			owner := mload(0x00)
		}
	}
}
