// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {CurrencyState} from "test/shared/states/CurrencyState.sol";
import {AaveConfig, CompoundV2Config, CompoundV3Config} from "test/shared/states/DataTypes.sol";
import {Assertion} from "test/shared/utils/Assertion.sol";
import {Deployer} from "test/shared/utils/Deployer.sol";
import {Fork} from "test/shared/utils/Fork.sol";
import {Utils} from "test/shared/utils/Utils.sol";

abstract contract BaseTest is Test, Assertion, Fork, Deployer, Utils {
	using CurrencyLibrary for Currency;

	AaveConfig aaveV2Config;
	AaveConfig aaveV3Config;

	CompoundV2Config compV2Config;
	CompoundV3Config compV3Config;

	function setUp() public virtual {}

	function _setUp(uint256 chainId, bool forkOnBlock) internal virtual {
		setUpForks(forkOnBlock);
		fork(chainId);

		setUpCurrencies(chainId);
		setUpLenders(chainId);

		// deploy configuration contracts

		deployCreate3Factory();
		deployAddressResolver();
		deployACLManager();

		// deploy utils contracts

		deployFeedResolver();
		deployCTokenRegistry(compV2Config);

		setUpFeeds(chainId);

		// deploy lending adapters

		deployAaveV2Adapter(aaveV2Config);
		deployAaveV3Adapter(aaveV3Config);
		deployCompoundV2Adapter(compV2Config);
		deployCompoundV3Adapter(compV3Config);
	}

	function deployConfigurations() internal {
		deployCreate3Factory();
		deployAddressResolver();
		deployACLManager();
		deployFeedResolver();
		deployCTokenRegistry(compV2Config);
	}

	function deployLenders() internal {
		deployAaveV2Adapter(aaveV2Config);
		deployAaveV3Adapter(aaveV3Config);
		deployCompoundV2Adapter(compV2Config);
		deployCompoundV3Adapter(compV3Config);
	}

	function setUpLenders(uint256 chainId) internal {
		if (chainId == ETHEREUM_CHAIN_ID) {
			aaveV2Config = AaveConfig({
				protocol: AAVE_V2_ID,
				provider: 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5,
				lendingPool: 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9,
				incentives: 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5,
				oracle: 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9,
				denomination: ETH
			});

			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
				lendingPool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
				incentives: 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb,
				oracle: 0x54586bE62E3c3580375aE3723C145253060Ca0C2,
				denomination: USD
			});

			compV2Config = CompoundV2Config({
				protocol: COMP_V2_ID,
				comptroller: 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B,
				oracle: 0x50ce56A3239671Ab62f185704Caedf626352741e,
				cNative: toCurrency(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5),
				cETH: toCurrency(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5)
			});

			compV3Config = CompoundV3Config({
				protocol: COMP_V3_ID,
				configurator: 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3,
				rewards: 0x1B0e765F6224C21223AeA2af16c1C46E38885a40,
				cWETH: toCurrency(0xA17581A9E3356d9A858b789D68B4d866e593aE94),
				cUSDC: toCurrency(0xc3d688B66703497DAA19211EEdff47f25384cdc3),
				cUSDCe: ZERO
			});
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
				lendingPool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
				incentives: 0x929EC64c34a17401F460460D4B9390518E5B473e,
				oracle: 0xD81eb3728a631871a7eBBaD631b5f424909f0c77,
				denomination: USD
			});

			compV2Config = CompoundV2Config({
				protocol: toBytes32("SONNE"),
				comptroller: 0x60CF091cD3f50420d50fD7f707414d0DF4751C58,
				oracle: 0x91579f47f7826471C08B0008eE9C778aaB2989fD,
				cNative: ZERO,
				cETH: toCurrency(0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E)
			});
		} else if (chainId == POLYGON_CHAIN_ID) {
			aaveV2Config = AaveConfig({
				protocol: AAVE_V2_ID,
				provider: 0xd05e3E715d945B59290df0ae8eF85c1BdB684744,
				lendingPool: 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf,
				incentives: 0x357D51124f59836DeD84c8a1730D72B749d8BC23,
				oracle: 0x0229F777B0fAb107F9591a41d5F02E4e98dB6f2d,
				denomination: ETH
			});

			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
				lendingPool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
				incentives: 0x929EC64c34a17401F460460D4B9390518E5B473e,
				oracle: 0xb023e699F5a33916Ea823A16485e259257cA8Bd1,
				denomination: USD
			});

			compV2Config = CompoundV2Config({
				protocol: toBytes32("KEOM"),
				comptroller: 0x5B7136CFFd40Eee5B882678a5D02AA25A48d669F,
				oracle: 0x828fb251167145F89cd479f9D71a5A762F23BF13,
				cNative: toCurrency(0x7854D4Cfa7d0B877E399bcbDFfb49536d7A14fc7),
				cETH: toCurrency(0x44010CBf1EC8B8D8275d86D8e28278C06DD07C48)
			});

			compV3Config = CompoundV3Config({
				protocol: COMP_V3_ID,
				configurator: 0x83E0F742cAcBE66349E3701B171eE2487a26e738,
				rewards: 0x45939657d1CA34A8FA39A924B71D28Fe8431e581,
				cWETH: ZERO,
				cUSDC: ZERO,
				cUSDCe: toCurrency(0xF25212E676D1F7F89Cd72fFEe66158f541246445)
			});
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
				lendingPool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
				incentives: 0x929EC64c34a17401F460460D4B9390518E5B473e,
				oracle: 0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7,
				denomination: USD
			});

			compV2Config = CompoundV2Config({
				protocol: toBytes32("LODE"),
				comptroller: 0xa86DD95c210dd186Fa7639F93E4177E97d057576,
				oracle: 0xcCf9393df2F656262FD79599175950faB4D4ec01,
				cNative: toCurrency(0x2193c45244AF12C280941281c8aa67dD08be0a64),
				cETH: toCurrency(0x2193c45244AF12C280941281c8aa67dD08be0a64)
			});

			compV3Config = CompoundV3Config({
				protocol: COMP_V3_ID,
				configurator: 0xb21b06D71c75973babdE35b49fFDAc3F82Ad3775,
				rewards: 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae,
				cWETH: ZERO,
				cUSDC: toCurrency(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf),
				cUSDCe: toCurrency(0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA)
			});
		}
	}

	function deal(Currency currency, address account, uint256 amount) internal {
		deal(currency.toAddress(), account, amount);
	}

	function getPrice(Currency base) internal view returns (uint256) {
		return feedRegistry.latestAnswerETH(base);
	}

	function getPrice(Currency base, address quote) internal view returns (uint256) {
		return feedRegistry.latestAnswer(base, quote);
	}
}
