// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

struct AaveConfig {
	bytes32 protocol;
	address provider;
	address lendingPool;
	address oracle;
	address incentives;
	address denomination;
}

struct CompoundV2Config {
	bytes32 protocol;
	address comptroller;
	address oracle;
	Currency cNative;
	Currency cETH;
}

struct CompoundV3Config {
	bytes32 protocol;
	address configurator;
	address rewards;
	Currency cWETH;
	Currency cUSDC;
	Currency cUSDCe;
}

struct Reward {
	Currency asset;
	uint256 accrued;
	uint256 balance;
}
