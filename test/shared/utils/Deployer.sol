// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ACLManager} from "src/configuration/ACLManager.sol";
import {AddressResolver} from "src/configuration/AddressResolver.sol";
import {AaveV2Adapter} from "src/modules/adapters/lenders/AaveV2Adapter.sol";
import {AaveV3Adapter} from "src/modules/adapters/lenders/AaveV3Adapter.sol";
import {CompoundV2Adapter} from "src/modules/adapters/lenders/CompoundV2Adapter.sol";
import {CompoundV3Adapter} from "src/modules/adapters/lenders/CompoundV3Adapter.sol";
import {ConvexCurveAdapter} from "src/modules/adapters/stakers/ConvexCurveAdapter.sol";
import {FeedRegistry} from "src/utils/FeedRegistry.sol";
import {Create3Factory} from "src/utils/Create3Factory.sol";
import {CTokenRegistry} from "src/utils/CTokenRegistry.sol";
import {BOOSTER} from "src/libraries/Constants.sol";
import {Currency} from "src/types/Currency.sol";
import {CurrencyState} from "test/shared/states/CurrencyState.sol";
import {AaveConfig, CompoundV2Config, CompoundV3Config} from "test/shared/states/DataTypes.sol";

contract Deployer is CommonBase, CurrencyState {
	AddressResolver resolver;
	ACLManager aclManager;

	Create3Factory create3Factory;
	FeedRegistry feedRegistry;
	CTokenRegistry cTokenRegistry;

	AaveV2Adapter aaveV2Adapter;
	AaveV3Adapter aaveV3Adapter;
	CompoundV2Adapter compV2Adapter;
	CompoundV3Adapter compV3Adapter;

	ConvexCurveAdapter cvxCrvAdapter;

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

	function deployFeedResolver() internal {
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

			vm.label(BOOSTER, "ConvexBooster");
		}
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
