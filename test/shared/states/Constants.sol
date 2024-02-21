// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Constants {
	uint256 constant ETHEREUM_CHAIN_ID = 1;
	uint256 constant OPTIMISM_CHAIN_ID = 10;
	uint256 constant POLYGON_CHAIN_ID = 137;
	uint256 constant ARBITRUM_CHAIN_ID = 42161;

	uint256 constant ETHEREUM_FORK_BLOCK = 18939880;
	uint256 constant OPTIMISM_FORK_BLOCK = 114422176;
	uint256 constant POLYGON_FORK_BLOCK = 51961000;
	uint256 constant ARBITRUM_FORK_BLOCK = 167285403;

	// Protocol IDs

	bytes32 constant AAVE_V2_ID = bytes32(bytes("AAVE-V2"));
	bytes32 constant AAVE_V3_ID = bytes32(bytes("AAVE-V3"));
	bytes32 constant COMP_V2_ID = bytes32(bytes("COMP-V2"));
	bytes32 constant COMP_V3_ID = bytes32(bytes("COMP-V3"));
	bytes32 constant CRV_ID = bytes32(bytes("CRV"));
	bytes32 constant CVX_ID = bytes32(bytes("CVX"));
	bytes32 constant UNI_V3_ID = bytes32(bytes("UNI-V3"));

	// Denominations

	address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address constant USD = 0x0000000000000000000000000000000000000348;
	address constant MATIC = 0x0000000000000000000000000000000000001010;

	uint256 constant WAD = 1e18;
}
