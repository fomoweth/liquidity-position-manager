// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Encoder} from "test/shared/utils/Encoder.sol";
import {Constants} from "test/shared/states/Constants.sol";

abstract contract CurrencyState is Constants, Encoder {
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
	Currency OP;
	Currency UNI;

	// Stablecoins
	Currency DAI;
	Currency FRAX;
	Currency USDC;
	Currency USDT;

	function setUpCurrencies(uint256 chainId) internal virtual {
		if (chainId == ETHEREUM_CHAIN_ID) {
			WRAPPED_NATIVE = toCurrency(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
			WETH = WRAPPED_NATIVE;
			WBTC = toCurrency(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

			stETH = toCurrency(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
			wstETH = toCurrency(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
			frxETH = toCurrency(0x5E8422345238F34275888049021821E8E08CAa1f);
			sfrxETH = toCurrency(0xac3E018457B222d93114458476f3E3416Abbe38F);
			cbETH = toCurrency(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
			rETH = toCurrency(0xae78736Cd615f374D3085123A210448E74Fc6393);

			AAVE = toCurrency(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
			COMP = toCurrency(0xc00e94Cb662C3520282E6f5717214004A7f26888);
			CRV = toCurrency(0xD533a949740bb3306d119CC777fa900bA034cd52);
			CVX = toCurrency(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
			FXS = toCurrency(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
			UNI = toCurrency(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

			DAI = toCurrency(0x6B175474E89094C44Da98b954EedeAC495271d0F);
			FRAX = toCurrency(0x853d955aCEf822Db058eb8505911ED77F175b99e);
			USDC = toCurrency(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
			USDT = toCurrency(0xdAC17F958D2ee523a2206206994597C13D831ec7);
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			WRAPPED_NATIVE = toCurrency(0x4200000000000000000000000000000000000006);
			WETH = WRAPPED_NATIVE;
			WBTC = toCurrency(0x68f180fcCe6836688e9084f035309E29Bf0A2095);

			wstETH = toCurrency(0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb);
			frxETH = toCurrency(0x6806411765Af15Bddd26f8f544A34cC40cb9838B);
			sfrxETH = toCurrency(0x484c2D6e3cDd945a8B2DF735e079178C1036578c);
			cbETH = toCurrency(0xadDb6A0412DE1BA0F936DCaeb8Aaa24578dcF3B2);
			rETH = toCurrency(0x9Bcef72be871e61ED4fBbc7630889beE758eb81D);

			AAVE = toCurrency(0x76FB31fb4af56892A25e32cFC43De717950c9278);
			CRV = toCurrency(0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53);
			FXS = toCurrency(0x67CCEA5bb16181E7b4109c9c2143c24a1c2205Be);
			OP = toCurrency(0x4200000000000000000000000000000000000042);
			UNI = toCurrency(0x6fd9d7AD17242c41f7131d257212c54A0e816691);

			DAI = toCurrency(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
			FRAX = toCurrency(0x2E3D870790dC77A83DD1d18184Acc7439A53f475);
			USDC = toCurrency(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
			USDT = toCurrency(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
		} else if (chainId == POLYGON_CHAIN_ID) {
			WRAPPED_NATIVE = toCurrency(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
			WMATIC = WRAPPED_NATIVE;
			WETH = toCurrency(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
			WBTC = toCurrency(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);

			wstETH = toCurrency(0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD);
			frxETH = toCurrency(0xEe327F889d5947c1dc1934Bb208a1E792F953E96);
			sfrxETH = toCurrency(0x6d1FdBB266fCc09A16a22016369210A15bb95761);
			cbETH = toCurrency(0x4b4327dB1600B8B1440163F667e199CEf35385f5);
			rETH = toCurrency(0x0266F4F08D82372CF0FcbCCc0Ff74309089c74d1);
			MaticX = toCurrency(0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6);
			stMATIC = toCurrency(0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4);

			AAVE = toCurrency(0xD6DF932A45C0f255f85145f286eA0b292B21C90B);
			COMP = toCurrency(0x8505b9d2254A7Ae468c0E9dd10Ccea3A837aef5c);
			CRV = toCurrency(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
			CVX = toCurrency(0x4257EA7637c355F81616050CbB6a9b709fd72683);
			FXS = toCurrency(0x1a3acf6D19267E2d3e7f898f42803e90C9219062);
			// FXS = toCurrency(0x3e121107F6F22DA4911079845a470757aF4e1A1b); // FXS PoS
			UNI = toCurrency(0xb33EaAd8d922B1083446DC23f610c2567fB5180f);

			DAI = toCurrency(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
			FRAX = toCurrency(0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89);
			USDC = toCurrency(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
			USDT = toCurrency(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			WRAPPED_NATIVE = toCurrency(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
			WETH = WRAPPED_NATIVE;
			WBTC = toCurrency(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);

			wstETH = toCurrency(0x5979D7b546E38E414F7E9822514be443A4800529);
			frxETH = toCurrency(0x178412e79c25968a32e89b11f63B33F733770c2A);
			sfrxETH = toCurrency(0x95aB45875cFFdba1E5f451B950bC2E42c0053f39);
			cbETH = toCurrency(0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f);
			rETH = toCurrency(0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8);

			ARB = toCurrency(0x912CE59144191C1204E64559FE8253a0e49E6548);
			AAVE = toCurrency(0xba5DdD1f9d7F570dc94a51479a000E3BCE967196);
			COMP = toCurrency(0x354A6dA3fcde098F8389cad84b0182725c6C91dE);
			CRV = toCurrency(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
			CVX = toCurrency(0xb952A807345991BD529FDded05009F5e80Fe8F45);
			FXS = toCurrency(0x9d2F299715D94d8A7E6F5eaa8E654E8c74a988A7);
			UNI = toCurrency(0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0);

			DAI = toCurrency(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
			FRAX = toCurrency(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
			USDC = toCurrency(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
			USDT = toCurrency(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
		}
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
}
