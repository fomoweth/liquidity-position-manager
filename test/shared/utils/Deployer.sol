// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {ACLManager} from "src/configuration/ACLManager.sol";
import {AddressResolver} from "src/configuration/AddressResolver.sol";
import {ModuleRegistry} from "src/configuration/ModuleRegistry.sol";
import {LendingDispatcher} from "src/modules/adapters/LendingDispatcher.sol";
import {AaveV2Adapter} from "src/modules/adapters/lenders/AaveV2Adapter.sol";
import {AaveV3Adapter} from "src/modules/adapters/lenders/AaveV3Adapter.sol";
import {CompoundV2Adapter} from "src/modules/adapters/lenders/CompoundV2Adapter.sol";
import {CompoundV3Adapter} from "src/modules/adapters/lenders/CompoundV3Adapter.sol";
import {ConvexCurveAdapter} from "src/modules/adapters/stakers/ConvexCurveAdapter.sol";
import {CurveAdapter} from "src/modules/adapters/stakers/CurveAdapter.sol";
import {V3StakerAdapter} from "src/modules/adapters/stakers/V3StakerAdapter.sol";
import {FeedRegistry} from "src/utils/FeedRegistry.sol";
import {Create3Factory} from "src/utils/Create3Factory.sol";
import {CTokenRegistry} from "src/utils/CTokenRegistry.sol";
import {ClientFactory} from "src/ClientFactory.sol";
import {Client} from "src/Client.sol";
import {BOOSTER, UNISWAP_V3_NFT, UNISWAP_V3_STAKER} from "src/libraries/Constants.sol";
import {Currency} from "src/types/Currency.sol";
import {Currencies} from "test/shared/states/Currencies.sol";
import {AaveConfig, CompoundV2Config, CompoundV3Config} from "test/shared/states/DataTypes.sol";

contract Deployer is CommonBase, Currencies {
	ClientFactory factory;
	Client implementation;
	Client client;

	AddressResolver resolver;
	ACLManager aclManager;
	ModuleRegistry moduleRegistry;

	Create3Factory create3Factory;
	FeedRegistry feedRegistry;
	CTokenRegistry cTokenRegistry;

	LendingDispatcher lendingDispatcher;

	AaveV2Adapter aaveV2Adapter;
	AaveV3Adapter aaveV3Adapter;
	CompoundV2Adapter compV2Adapter;
	CompoundV3Adapter compV3Adapter;

	ConvexCurveAdapter cvxCrvAdapter;
	CurveAdapter crvAdapter;
	V3StakerAdapter v3StakerAdapter;

	function deployCreate3Factory() internal {
		vm.label(address(create3Factory = new Create3Factory()), "Create3Factory");
	}

	function deployAddressResolver() internal {
		vm.label(address(resolver = new AddressResolver(address(this))), "AddressResolver");

		resolver.setACLAdmin(address(this));
	}

	function deployACLManager() internal {
		aclManager = ACLManager(create3("ACLManager", "ACL_MANAGER", type(ACLManager).creationCode));

		aclManager.initialize(address(resolver));
		aclManager.addFactoryAdmin(address(this));
		aclManager.addModuleListingAdmin(address(this));
		aclManager.addReserveListingAdmin(address(this));
		aclManager.addFeedListingAdmin(address(this));

		resolver.setACLManager(address(aclManager));
	}

	function deployClientFactory() internal {
		vm.label(address(implementation = new Client(address(resolver))), "Client Implementation");

		factory = ClientFactory(create3("ClientFactory", "CLIENT_FACTORY", type(ClientFactory).creationCode));

		factory.initialize(address(resolver));
		factory.setImplementation(address(implementation));

		resolver.setClientFactory(address(factory));
	}

	function deployClient() internal {
		vm.label(address(client = Client(payable(factory.deploy()))), "Client");
	}

	function deployModuleRegistry() internal {
		moduleRegistry = ModuleRegistry(
			create3("ModuleRegistry", "MODULE_REGISTRY", type(ModuleRegistry).creationCode)
		);

		moduleRegistry.initialize(address(resolver));

		resolver.setModuleRegistry(address(moduleRegistry));
	}

	function deployFeedRegistry() internal {
		feedRegistry = FeedRegistry(
			create3(
				"FeedRegistry",
				"FEED_REGISTRY",
				abi.encodePacked(type(FeedRegistry).creationCode, abi.encode(WRAPPED_NATIVE, WETH, WBTC))
			)
		);

		feedRegistry.initialize(address(resolver));

		resolver.setFeedRegistry(address(feedRegistry));
	}

	function deployCTokenRegistry(CompoundV2Config memory config) internal {
		if (config.protocol != bytes32(0)) {
			cTokenRegistry = CTokenRegistry(
				create3(
					"CTokenRegistry",
					"CTOKEN_REGISTRY",
					abi.encodePacked(
						type(CTokenRegistry).creationCode,
						abi.encode(
							config.protocol,
							config.comptroller,
							config.cNative,
							config.cETH,
							WRAPPED_NATIVE,
							WETH
						)
					)
				)
			);

			cTokenRegistry.initialize(address(resolver));
			cTokenRegistry.registerCTokens(cTokenRegistry.getCTokens());
		}
	}

	function deployLendingDispatcher() internal {
		lendingDispatcher = LendingDispatcher(
			create3(
				"LendingDispatcher",
				"LENDING_DISPATCHER",
				abi.encodePacked(
					type(LendingDispatcher).creationCode,
					abi.encode(address(resolver), bytes32(bytes("LENDING_DISPATCHER")), WRAPPED_NATIVE)
				)
			)
		);

		resolver.setLendingDispatcher(address(lendingDispatcher));

		bytes4[] memory signatures = new bytes4[](13);

		signatures[0] = LendingDispatcher.supply.selector;
		signatures[1] = LendingDispatcher.borrow.selector;
		signatures[2] = LendingDispatcher.repay.selector;
		signatures[3] = LendingDispatcher.redeem.selector;
		signatures[4] = LendingDispatcher.enterMarket.selector;
		signatures[5] = LendingDispatcher.exitMarket.selector;
		signatures[6] = LendingDispatcher.claimRewards.selector;
		signatures[7] = LendingDispatcher.getAccountLiquidity.selector;
		signatures[8] = LendingDispatcher.getSupplyBalance.selector;
		signatures[9] = LendingDispatcher.getBorrowBalance.selector;
		signatures[10] = LendingDispatcher.getReserveData.selector;
		signatures[11] = LendingDispatcher.getAssetPrice.selector;
		signatures[12] = LendingDispatcher.getLtv.selector;

		moduleRegistry.register(address(lendingDispatcher), signatures);
	}

	function deployStakingDispatcher() internal {
		//
	}

	function deployAaveV2Adapter(AaveConfig memory config) internal {
		if (config.protocol != bytes32(0)) {
			aaveV2Adapter = AaveV2Adapter(
				create3(
					"AaveV2Adapter",
					"AAVE_V2_ADAPTER",
					abi.encodePacked(
						type(AaveV2Adapter).creationCode,
						abi.encode(
							address(resolver),
							config.protocol,
							config.lendingPool,
							config.incentives,
							config.oracle,
							config.denomination,
							feedRegistry.getFeed(WETH, USD),
							WRAPPED_NATIVE,
							WETH
						)
					)
				)
			);

			resolver.setAddress(config.protocol, address(aaveV2Adapter));

			vm.label(config.lendingPool, "LendingPoolV2");
			vm.label(config.incentives, "IncentivesController");
			vm.label(config.oracle, "AaveV2Oracle");
		}
	}

	function deployAaveV3Adapter(AaveConfig memory config) internal {
		if (config.protocol != bytes32(0)) {
			aaveV3Adapter = AaveV3Adapter(
				create3(
					"AaveV3Adapter",
					"AAVE_V3_ADAPTER",
					abi.encodePacked(
						type(AaveV3Adapter).creationCode,
						abi.encode(
							address(resolver),
							config.protocol,
							config.lendingPool,
							config.incentives,
							config.oracle,
							config.denomination,
							feedRegistry.getFeed(WETH, USD),
							WRAPPED_NATIVE,
							WETH
						)
					)
				)
			);

			resolver.setAddress(config.protocol, address(aaveV3Adapter));

			vm.label(config.lendingPool, "LendingPoolV3");
			vm.label(config.incentives, "RewardsController");
			vm.label(config.oracle, "AaveV3Oracle");
		}
	}

	function deployCompoundV2Adapter(CompoundV2Config memory config) internal {
		if (config.protocol != bytes32(0)) {
			compV2Adapter = CompoundV2Adapter(
				create3(
					"CompoundV2Adapter",
					"COMPOUND_V2_ADAPTER",
					abi.encodePacked(
						type(CompoundV2Adapter).creationCode,
						abi.encode(
							address(resolver),
							address(cTokenRegistry),
							config.protocol,
							config.comptroller,
							config.oracle,
							config.cNative,
							config.cETH,
							feedRegistry.getFeed(WETH, USD),
							WRAPPED_NATIVE,
							WETH
						)
					)
				)
			);

			resolver.setAddress(config.protocol, address(compV2Adapter));

			vm.label(config.comptroller, "Comptroller");
			vm.label(config.oracle, "CompoundV2Oracle");
		}
	}

	function deployCompoundV3Adapter(CompoundV3Config memory config) internal {
		if (config.protocol != bytes32(0)) {
			compV3Adapter = CompoundV3Adapter(
				create3(
					"CompoundV3Adapter",
					"COMPOUND_V3_ADAPTER",
					abi.encodePacked(
						type(CompoundV3Adapter).creationCode,
						abi.encode(
							address(resolver),
							config.protocol,
							config.configurator,
							config.rewards,
							feedRegistry.getFeed(WETH, USD),
							WRAPPED_NATIVE,
							WETH
						)
					)
				)
			);

			resolver.setAddress(config.protocol, address(compV3Adapter));

			vm.label(config.configurator, "CometConfigurator");
			vm.label(config.rewards, "CometRewards");

			if (!config.cWETH.isZero()) vm.label(config.cWETH.toAddress(), "cWETH");
			if (!config.cUSDC.isZero()) vm.label(config.cUSDC.toAddress(), "cUSDC");
			if (!config.cUSDCe.isZero()) vm.label(config.cUSDCe.toAddress(), "cUSDCe");
		}
	}

	function deployConvexCurveAdapter() internal {
		if (!CVX.isZero()) {
			cvxCrvAdapter = ConvexCurveAdapter(
				create3(
					"ConvexCurveAdapter",
					"CONVEX_CURVE_ADAPTER",
					abi.encodePacked(
						type(ConvexCurveAdapter).creationCode,
						abi.encode(address(resolver), CVX_ID, WRAPPED_NATIVE, CRV, CVX)
					)
				)
			);

			resolver.setAddress(CVX_ID, address(cvxCrvAdapter));

			vm.label(BOOSTER, "ConvexBooster");
		}
	}

	function deployCurveAdapter() internal {
		crvAdapter = CurveAdapter(
			create3(
				"CurveAdapter",
				"CURVE_ADAPTER",
				abi.encodePacked(
					type(CurveAdapter).creationCode,
					abi.encode(address(resolver), CRV_ID, WRAPPED_NATIVE, CRV)
				)
			)
		);

		resolver.setAddress(CRV_ID, address(crvAdapter));
	}

	function deployV3StakerAdapter() internal {
		v3StakerAdapter = V3StakerAdapter(
			create3(
				"V3StakerAdapter",
				"V3_STAKER_ADAPTER",
				abi.encodePacked(
					type(V3StakerAdapter).creationCode,
					abi.encode(address(resolver), UNI_V3_ID, WRAPPED_NATIVE)
				)
			)
		);

		resolver.setAddress(UNI_V3_ID, address(v3StakerAdapter));

		vm.label(UNISWAP_V3_NFT, "NonfungiblePositionManager");
		vm.label(UNISWAP_V3_STAKER, "V3Staker");
	}

	function create3(
		string memory label,
		string memory salt,
		bytes memory bytecode
	) internal returns (address deployed) {
		vm.label(deployed = create3Factory.deploy(keccak256(bytes(salt)), bytecode), label);
	}

	function setFeed(address feed, Currency base, address quote) internal virtual override {
		feedRegistry.setFeed(feed, base, quote);
	}
}
