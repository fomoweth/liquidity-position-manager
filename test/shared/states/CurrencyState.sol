// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Encoder} from "test/shared/utils/Encoder.sol";
import {Constants} from "test/shared/states/Constants.sol";

abstract contract CurrencyState is CommonBase, Constants, Encoder {
	Currency constant NATIVE = CurrencyLibrary.NATIVE;
	Currency constant ZERO = CurrencyLibrary.ZERO;

	Currency WRAPPED_NATIVE;
	Currency WETH;
	Currency WBTC;
	Currency WMATIC;

	// Liquid Staking Tokens
	Currency stETH;
	Currency wstETH;
	Currency frxETH;
	Currency sfrxETH;
	Currency cbETH;
	Currency rETH;
	Currency stMATIC;
	Currency MaticX;

	// Reward Tokens
	Currency ARB;
	Currency AAVE;
	Currency COMP;
	Currency CRV;
	Currency CVX;
	Currency FXS;
	Currency LINK;
	Currency OP;
	Currency UNI;

	// Stablecoins
	Currency DAI;
	Currency FRAX;
	Currency MIM;
	Currency USDC;
	Currency USDT;

	function setUpCurrencies(uint256 chainId) internal virtual {
		if (chainId == ETHEREUM_CHAIN_ID) {
			WRAPPED_NATIVE = setCurrency(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
			WETH = WRAPPED_NATIVE;
			WBTC = setCurrency(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

			stETH = setCurrency(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
			wstETH = setCurrency(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
			frxETH = setCurrency(0x5E8422345238F34275888049021821E8E08CAa1f);
			sfrxETH = setCurrency(0xac3E018457B222d93114458476f3E3416Abbe38F);
			cbETH = setCurrency(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
			rETH = setCurrency(0xae78736Cd615f374D3085123A210448E74Fc6393);

			AAVE = setCurrency(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
			COMP = setCurrency(0xc00e94Cb662C3520282E6f5717214004A7f26888);
			CRV = setCurrency(0xD533a949740bb3306d119CC777fa900bA034cd52);
			CVX = setCurrency(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
			FXS = setCurrency(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
			LINK = setCurrency(0x514910771AF9Ca656af840dff83E8264EcF986CA);
			UNI = setCurrency(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

			DAI = setCurrency(0x6B175474E89094C44Da98b954EedeAC495271d0F);
			FRAX = setCurrency(0x853d955aCEf822Db058eb8505911ED77F175b99e);
			MIM = setCurrency(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
			USDC = setCurrency(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
			USDT = setCurrency(0xdAC17F958D2ee523a2206206994597C13D831ec7);
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			WRAPPED_NATIVE = setCurrency(0x4200000000000000000000000000000000000006);
			WETH = WRAPPED_NATIVE;
			WBTC = setCurrency(0x68f180fcCe6836688e9084f035309E29Bf0A2095);

			wstETH = setCurrency(0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb);
			frxETH = setCurrency(0x6806411765Af15Bddd26f8f544A34cC40cb9838B);
			sfrxETH = setCurrency(0x484c2D6e3cDd945a8B2DF735e079178C1036578c);
			cbETH = setCurrency(0xadDb6A0412DE1BA0F936DCaeb8Aaa24578dcF3B2);
			rETH = setCurrency(0x9Bcef72be871e61ED4fBbc7630889beE758eb81D);

			AAVE = setCurrency(0x76FB31fb4af56892A25e32cFC43De717950c9278);
			CRV = setCurrency(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
			FXS = setCurrency(0x67CCEA5bb16181E7b4109c9c2143c24a1c2205Be);
			LINK = setCurrency(0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6);
			OP = setCurrency(0x4200000000000000000000000000000000000042);
			UNI = setCurrency(0x6fd9d7AD17242c41f7131d257212c54A0e816691);

			DAI = setCurrency(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
			FRAX = setCurrency(0x2E3D870790dC77A83DD1d18184Acc7439A53f475);
			MIM = setCurrency(0xB153FB3d196A8eB25522705560ac152eeEc57901);
			USDC = setCurrency(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
			USDT = setCurrency(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
		} else if (chainId == POLYGON_CHAIN_ID) {
			WRAPPED_NATIVE = setCurrency(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
			WMATIC = WRAPPED_NATIVE;
			WETH = setCurrency(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
			WBTC = setCurrency(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);

			wstETH = setCurrency(0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD);
			frxETH = setCurrency(0xEe327F889d5947c1dc1934Bb208a1E792F953E96);
			sfrxETH = setCurrency(0x6d1FdBB266fCc09A16a22016369210A15bb95761);
			cbETH = setCurrency(0x4b4327dB1600B8B1440163F667e199CEf35385f5);
			rETH = setCurrency(0x0266F4F08D82372CF0FcbCCc0Ff74309089c74d1);
			MaticX = setCurrency(0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6);
			stMATIC = setCurrency(0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4);

			AAVE = setCurrency(0xD6DF932A45C0f255f85145f286eA0b292B21C90B);
			COMP = setCurrency(0x8505b9d2254A7Ae468c0E9dd10Ccea3A837aef5c);
			CRV = setCurrency(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
			CVX = setCurrency(0x4257EA7637c355F81616050CbB6a9b709fd72683);
			FXS = setCurrency(0x1a3acf6D19267E2d3e7f898f42803e90C9219062);
			LINK = setCurrency(0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39);
			UNI = setCurrency(0xb33EaAd8d922B1083446DC23f610c2567fB5180f);

			DAI = setCurrency(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
			FRAX = setCurrency(0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89);
			MIM = setCurrency(0x49a0400587A7F65072c87c4910449fDcC5c47242);
			USDC = setCurrency(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
			USDT = setCurrency(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			WRAPPED_NATIVE = setCurrency(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
			WETH = WRAPPED_NATIVE;
			WBTC = setCurrency(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);

			wstETH = setCurrency(0x5979D7b546E38E414F7E9822514be443A4800529);
			frxETH = setCurrency(0x178412e79c25968a32e89b11f63B33F733770c2A);
			sfrxETH = setCurrency(0x95aB45875cFFdba1E5f451B950bC2E42c0053f39);
			cbETH = setCurrency(0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f);
			rETH = setCurrency(0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8);

			ARB = setCurrency(0x912CE59144191C1204E64559FE8253a0e49E6548);
			AAVE = setCurrency(0xba5DdD1f9d7F570dc94a51479a000E3BCE967196);
			COMP = setCurrency(0x354A6dA3fcde098F8389cad84b0182725c6C91dE);
			CRV = setCurrency(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
			CVX = setCurrency(0xb952A807345991BD529FDded05009F5e80Fe8F45);
			FXS = setCurrency(0x9d2F299715D94d8A7E6F5eaa8E654E8c74a988A7);
			LINK = setCurrency(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4);
			UNI = setCurrency(0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0);

			DAI = setCurrency(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
			FRAX = setCurrency(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
			MIM = setCurrency(0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A);
			USDC = setCurrency(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
			USDT = setCurrency(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
		}
	}

	function setUpFeeds(uint256 chainId) internal virtual {
		if (chainId == ETHEREUM_CHAIN_ID) {
			setFeed(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, WETH, USD);
			setFeed(0xAc559F25B1619171CbC396a50854A3240b6A4e99, WETH, BTC);

			setFeed(0xdeb288F737066589598e9214E782fa5A8eD689e8, WBTC, ETH);
			setFeed(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, WBTC, USD);

			setFeed(0x86392dC19c0b719886221c78AB11eb8Cf5c52812, stETH, ETH);
			setFeed(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8, stETH, USD);
			setFeed(0xF017fcB346A1885194689bA23Eff2fE6fA5C483b, cbETH, ETH);
			setFeed(0x536218f9E9Eb48863970252233c8F271f554C2d0, rETH, ETH);

			setFeed(0x6Df09E975c830ECae5bd4eD9d90f3A95a4f88012, AAVE, ETH);
			setFeed(0x547a514d5e3769680Ce22B2361c10Ea13619e8a9, AAVE, USD);
			setFeed(0x1B39Ee86Ec5979ba5C322b826B3ECb8C79991699, COMP, ETH);
			setFeed(0xdbd020CAeF83eFd542f4De03e3cF0C28A4428bd5, COMP, USD);
			setFeed(0x8a12Be339B0cD1829b91Adc01977caa5E9ac121e, CRV, ETH);
			setFeed(0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f, CRV, USD);
			setFeed(0xC9CbF687f43176B302F03f5e58470b77D07c61c6, CVX, ETH);
			setFeed(0xd962fC30A72A84cE50161031391756Bf2876Af5D, CVX, USD);
			setFeed(0x6Ebc52C8C1089be9eB3945C4350B68B8E4C2233f, FXS, USD);
			setFeed(0xDC530D9457755926550b59e8ECcdaE7624181557, LINK, ETH);
			setFeed(0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c, LINK, USD);
			setFeed(0xD6aA3D25116d8dA79Ea0246c4826EB951872e02e, UNI, ETH);
			setFeed(0x553303d460EE0afB37EdFf9bE42922D8FF63220e, UNI, USD);

			setFeed(0x773616E4d11A78F511299002da57A0a94577F1f4, DAI, ETH);
			setFeed(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9, DAI, USD);
			setFeed(0x14d04Fff8D21bd62987a5cE9ce543d2F1edF5D3E, FRAX, ETH);
			setFeed(0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD, FRAX, USD);
			setFeed(0x7A364e8770418566e3eb2001A96116E6138Eb32F, MIM, USD);
			setFeed(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4, USDC, ETH);
			setFeed(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6, USDC, USD);
			setFeed(0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46, USDT, ETH);
			setFeed(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D, USDT, USD);
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			setFeed(0x13e3Ee699D1909E989722E753853AE30b17e08c5, WETH, USD);
			setFeed(0xe4b9bcD7d0AA917f19019165EB89BdbbF36d2cBe, WETH, BTC);

			setFeed(0x718A5788b89454aAE3A028AE9c111A29Be6c2a6F, WBTC, USD);

			setFeed(0x524299Ab0987a7c4B3c8022a35669DdcdC715a10, wstETH, ETH);
			setFeed(0x698B585CbC4407e2D54aa898B2600B53C68958f7, wstETH, USD);
			setFeed(0x138b809B8472fF09Cd3E075E6EcbB2e42D41d870, cbETH, ETH);
			setFeed(0xb429DE60943a8e6DeD356dca2F93Cd31201D9ed0, rETH, ETH);

			setFeed(0x338ed6787f463394D24813b297401B9F05a8C9d1, AAVE, USD);
			setFeed(0xe1011160d78a80E2eEBD60C228EEf7af4Dfcd4d7, COMP, USD);
			setFeed(0xbD92C6c284271c227a1e0bF1786F468b539f51D9, CRV, USD);
			setFeed(0xB9B16330671067B1b062B9aC2eFd2dB75F03436E, FXS, USD);
			setFeed(0x464A1515ADc20de946f8d0DEB99cead8CEAE310d, LINK, ETH);
			setFeed(0xCc232dcFAAE6354cE191Bd574108c1aD03f86450, LINK, USD);
			setFeed(0x0D276FC14719f9292D5C1eA2198673d1f4269246, OP, USD);
			setFeed(0x11429eE838cC01071402f21C219870cbAc0a59A0, UNI, USD);

			setFeed(0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6, DAI, USD);
			setFeed(0xc7D132BeCAbE7Dcc4204841F33bae45841e41D9C, FRAX, USD);
			setFeed(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3, USDC, USD);
			setFeed(0xECef79E109e997bCA29c1c0897ec9d7b03647F5E, USDT, USD);
		} else if (chainId == POLYGON_CHAIN_ID) {
			setFeed(0xF9680D99D6C9589e2a93a78A04A279e509205945, WETH, USD);

			setFeed(0x19b0F0833C78c0848109E3842D34d2fDF2cA69BA, WBTC, ETH); // BTC/ETH
			setFeed(0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6, WBTC, USD);
			setFeed(0xA338e0492B2F944E9F8C0653D3AD1484f2657a37, WBTC, BTC);

			setFeed(0x327e23A4855b6F663a28c5161541d69Af8973302, WMATIC, ETH);
			setFeed(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0, WMATIC, USD);
			setFeed(0x97371dF4492605486e23Da797fA68e55Fc38a13f, stMATIC, USD);
			setFeed(0x0e1120524e14Bd7aD96Ea76A1b1dD699913e2a45, MaticX, USD);

			setFeed(0x0a6a03CdF7d0b48d4e4BA8e362A4FfC3aAC4f3c0, cbETH, ETH);
			setFeed(0x10f964234cae09cB6a9854B56FF7D4F38Cda5E6a, wstETH, ETH);

			setFeed(0xbE23a3AA13038CfC28aFd0ECe4FdE379fE7fBfc4, AAVE, ETH);
			setFeed(0x72484B12719E23115761D5DA1646945632979bB6, AAVE, USD);
			setFeed(0x2A8758b7257102461BC958279054e372C2b1bDE6, COMP, USD);
			setFeed(0x1CF68C76803c9A415bE301f50E82e44c64B7F1D4, CRV, ETH);
			setFeed(0x336584C8E6Dc19637A5b36206B1c79923111b405, CRV, USD);
			setFeed(0x5ec151834040B4D453A1eA46aA634C1773b36084, CVX, USD);
			setFeed(0x6C0fe985D3cAcbCdE428b84fc9431792694d0f51, FXS, USD);
			setFeed(0xb77fa460604b9C6435A235D057F7D319AC83cb53, LINK, ETH);
			setFeed(0xd9FFdb71EbE7496cC440152d43986Aae0AB76665, LINK, USD);
			setFeed(0x162d8c5bF15eB6BEe003a1ffc4049C92114bc931, UNI, ETH);
			setFeed(0xdf0Fb4e4F928d2dCB76f438575fDD8682386e13C, UNI, USD);

			setFeed(0xFC539A559e170f848323e19dfD66007520510085, DAI, ETH);
			setFeed(0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D, DAI, USD);
			setFeed(0x00DBeB1e45485d53DF7C2F0dF1Aa0b6Dc30311d3, FRAX, USD);
			setFeed(0xd133F916e04ed5D67b231183d85Be12eAA018320, MIM, USD);
			setFeed(0xefb7e6be8356cCc6827799B6A7348eE674A80EaE, USDC, ETH);
			setFeed(0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7, USDC, USD);
			setFeed(0xf9d5AAC6E5572AEFa6bd64108ff86a222F69B64d, USDT, ETH);
			setFeed(0x0A6513e40db6EB1b165753AD52E80663aeA50545, USDT, USD);
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			setFeed(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, WETH, USD);

			setFeed(0xc5a90A6d7e4Af242dA238FFe279e9f2BA0c64B2e, WBTC, ETH); // BTC/ETH
			setFeed(0xd0C7101eACbB49F3deCcCc166d238410D6D46d57, WBTC, USD);
			setFeed(0x0017abAc5b6f291F9164e35B1234CA1D697f9CF4, WBTC, BTC);

			setFeed(0xb523AE262D20A936BC152e6023996e46FDC2A95D, wstETH, USD);
			setFeed(0xa668682974E3f121185a3cD94f00322beC674275, cbETH, USD);
			setFeed(0xD6aB2298946840262FcC278fF31516D39fF611eF, rETH, USD);

			setFeed(0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6, ARB, USD);
			setFeed(0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034, AAVE, USD);
			setFeed(0xe7C53FFd03Eb6ceF7d208bC4C13446c76d1E5884, COMP, USD);
			setFeed(0xaebDA2c976cfd1eE1977Eac079B4382acb849325, CRV, USD);
			setFeed(0x851175a919f36c8e30197c09a9A49dA932c2CC00, CVX, USD);
			setFeed(0x36a121448D74Fa81450c992A1a44B9b7377CD3a5, FXS, USD);
			setFeed(0xb7c8Fb1dB45007F98A68Da0588e1AA524C317f27, LINK, ETH);
			setFeed(0x86E53CF1B870786351Da77A57575e79CB55812CB, LINK, USD);
			setFeed(0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720, UNI, USD);

			setFeed(0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB, DAI, USD);
			setFeed(0x0809E3d38d1B4214958faf06D8b1B1a2b73f2ab8, FRAX, USD);
			setFeed(0x87121F6c9A9F6E90E59591E4Cf4804873f54A95b, MIM, USD);
			setFeed(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, USDC, USD);
			setFeed(0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7, USDT, USD);
		}
	}

	function setCurrency(address asset) internal virtual returns (Currency currency) {
		vm.label(asset, symbol((currency = toCurrency(asset))));
	}

	function symbol(Currency currency) internal view returns (string memory res) {
		res = callAndParseStringReturn(currency, 0x95d89b41);

		if (bytes(res).length == 0) return Strings.toHexString(currency.toId(), 20);
	}

	function name(Currency currency) internal view returns (string memory res) {
		res = callAndParseStringReturn(currency, 0x06fdde03);

		if (bytes(res).length == 0) return Strings.toHexString(currency.toId(), 3);
	}

	function callAndParseStringReturn(
		Currency currency,
		bytes4 selector
	) private view returns (string memory) {
		(bool success, bytes memory returndata) = currency.toAddress().staticcall(
			abi.encodeWithSelector(selector)
		);

		if (success) {
			if (returndata.length == 32) return bytes32ToString(abi.decode(returndata, (bytes32)));
			else if (returndata.length > 64) return abi.decode(returndata, (string));
		}

		return "";
	}

	function setFeed(address feed, Currency base, address quote) internal virtual;
}
