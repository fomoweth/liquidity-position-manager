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

struct AaveMarket {
	Currency aToken;
	Currency vdToken;
	Currency underlying;
	uint16 ltv;
	uint16 id;
}

struct CompoundV2Config {
	bytes32 protocol;
	address comptroller;
	address oracle;
	Currency cNative;
	Currency cETH;
	address denomination;
}

struct CompoundV3Config {
	bytes32 protocol;
	address configurator;
	address rewards;
}

struct CompoundMarket {
	Currency market;
	Currency underlying;
	uint16 ltv;
}
