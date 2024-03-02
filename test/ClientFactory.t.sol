// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Deployer} from "test/shared/utils/Deployer.sol";

// forge test -vvv --match-path test/ClientFactory.t.sol

contract ClientFactoryTest is Test, Deployer {
	function setUp() public {
		deployCreate3Factory();
		deployAddressResolver();
		deployACLManager();
		deployClientFactory();
	}

	function test_implementationSetUp() public {
		assertEq(factory.implementation(), address(implementation));
	}

	function test_implementationSetUp_revertIfNotAuthorized() public {
		vm.expectRevert(Errors.AccessDenied.selector);
		vm.prank(makeAddr("InvalidSender"));
		factory.setImplementation(address(0));
	}

	function test_deploy() public {
		deployClient();
		assertEq(factory.computeAddress(address(this)), address(client));
		assertEq(client.owner(), address(this));
	}
}
