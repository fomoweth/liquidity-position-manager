// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {ILender} from "src/interfaces/ILender.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {CurrencyState} from "test/shared/states/CurrencyState.sol";
import {CompoundV3Config, CompoundMarket} from "test/shared/states/DataTypes.sol";
import {Utils} from "./Utils.sol";

abstract contract CometUtils is CommonBase, CurrencyState, Utils {
	using CurrencyLibrary for Currency;
	using WadRayMath for uint256;

	CompoundV3Config compV3Config;

	function setUpComet(uint256 chainId) internal virtual {
		if (chainId == ETHEREUM_CHAIN_ID) {
			compV3Config = CompoundV3Config({
				protocol: COMP_V3_ID,
				configurator: 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3,
				rewards: 0x1B0e765F6224C21223AeA2af16c1C46E38885a40
			});
		} else if (chainId == POLYGON_CHAIN_ID) {
			compV3Config = CompoundV3Config({
				protocol: COMP_V3_ID,
				configurator: 0x83E0F742cAcBE66349E3701B171eE2487a26e738,
				rewards: 0x45939657d1CA34A8FA39A924B71D28Fe8431e581
			});
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			compV3Config = CompoundV3Config({
				protocol: COMP_V3_ID,
				configurator: 0xb21b06D71c75973babdE35b49fFDAc3F82Ad3775,
				rewards: 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae
			});
		}

		if (compV3Config.protocol != bytes32(0)) {
			vm.label(compV3Config.configurator, "CometConfigurator");
			vm.label(compV3Config.rewards, "CometRewards");
		}
	}

	function getCometMarkets(
		Currency[] memory assets
	) internal returns (CompoundMarket[] memory cometMarkets) {
		//
	}
}
