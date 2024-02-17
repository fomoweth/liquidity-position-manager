// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Chain
/// @notice Used for determining chain and chain info

abstract contract Chain {
	uint256 internal constant ETHEREUM_CHAIN_ID = 1;
	uint256 internal constant OPTIMISM_CHAIN_ID = 10;
	uint256 internal constant POLYGON_CHAIN_ID = 137;
	uint256 internal constant ARBITRUM_CHAIN_ID = 42161;

	address private constant ARB_SYS = 0x0000000000000000000000000000000000000064;

	function blockNumber() internal view returns (uint40 bn) {
		bool runningOnArbitrum = isArbitrum();

		assembly ("memory-safe") {
			switch runningOnArbitrum
			case 0x00 {
				bn := mod(number(), exp(0x02, 0x28))
			}
			default {
				let ptr := mload(0x40)

				mstore(ptr, 0xa3b1b31d00000000000000000000000000000000000000000000000000000000) // arbBlockNumber()

				if iszero(staticcall(gas(), ARB_SYS, ptr, 0x04, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				bn := mod(mload(0x00), exp(0x02, 0x28))
			}
		}
	}

	function blockTimestamp() internal view returns (uint40 bts) {
		assembly ("memory-safe") {
			bts := mod(timestamp(), exp(0x02, 0x28))
		}
	}

	function chainId() internal view returns (uint256 id) {
		assembly ("memory-safe") {
			id := chainid()
		}
	}

	function isEthereum() internal view returns (bool res) {
		assembly ("memory-safe") {
			res := eq(chainid(), ETHEREUM_CHAIN_ID)
		}
	}

	function isOptimism() internal view returns (bool res) {
		assembly ("memory-safe") {
			res := eq(chainid(), OPTIMISM_CHAIN_ID)
		}
	}

	function isPolygon() internal view returns (bool res) {
		assembly ("memory-safe") {
			res := eq(chainid(), POLYGON_CHAIN_ID)
		}
	}

	function isArbitrum() private view returns (bool res) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x051038f200000000000000000000000000000000000000000000000000000000) // arbOSVersion()

			res := and(staticcall(gas(), ARB_SYS, ptr, 0x04, 0x00, 0x20), eq(returndatasize(), 0x20))
		}
	}
}
