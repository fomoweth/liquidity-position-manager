// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ACLManager} from "src/configuration/ACLManager.sol";
import {AddressResolver} from "src/configuration/AddressResolver.sol";
import {Create3Factory} from "src/utils/Create3Factory.sol";
import {AaveV2Adapter} from "src/modules/adapters/lenders/AaveV2Adapter.sol";
import {AaveV3Adapter} from "src/modules/adapters/lenders/AaveV3Adapter.sol";
import {Currency} from "src/types/Currency.sol";
import {AaveConfig} from "test/shared/states/DataTypes.sol";

contract Deployer is CommonBase {
	AddressResolver resolver;
	ACLManager aclManager;
	Create3Factory create3Factory;

	AaveV2Adapter aaveV2Adapter;
	AaveV3Adapter aaveV3Adapter;

	function deployConfigurations() internal {
		deployCreate3Factory();
		deployAddressResolver();
		deployACLManager();
	}

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

		resolver.setACLManager(address(aclManager));
	}

	function deployAaveV2Adapter(
		AaveConfig memory config,
		Currency wrappedNative,
		Currency weth
	) internal returns (AaveV2Adapter adapter) {
		if (config.protocol != bytes32(0)) {
			adapter = AaveV2Adapter(
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
							wrappedNative,
							weth
						)
					)
				)
			);
		}
	}

	function deployAaveV3Adapter(
		AaveConfig memory config,
		Currency wrappedNative,
		Currency weth
	) internal returns (AaveV3Adapter adapter) {
		if (config.protocol != bytes32(0)) {
			adapter = AaveV3Adapter(
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
							wrappedNative,
							weth
						)
					)
				)
			);
		}
	}

	function create3(
		string memory label,
		string memory salt,
		bytes memory bytecode
	) internal returns (address deployed) {
		vm.label(deployed = create3Factory.deploy(keccak256(bytes(salt)), bytecode), label);
	}
}
