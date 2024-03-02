// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IClientFactory} from "src/interfaces/IClientFactory.sol";
import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Authority} from "src/base/Authority.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

/// @title ClientFactory

contract ClientFactory is IClientFactory, Authority, Initializable {
	using Clones for address;

	IAddressResolver internal resolver;

	address internal _implementation;

	constructor() {}

	function initialize(address _resolver) external initializer {
		resolver = IAddressResolver(_resolver);
	}

	function deploy() external payable returns (address client) {
		// deploy client via CREATE2
		client = implementation().cloneDeterministic(bytes32(bytes20(_msgSender())));

		// initialize deployed client with the address of deployer
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x439fab9100000000000000000000000000000000000000000000000000000000) // initialize(bytes)
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), 0x20)
			mstore(add(ptr, 0x44), caller())

			if iszero(call(gas(), client, 0x00, ptr, 0x64, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function computeAddress(address deployer) external view returns (address client) {
		if (deployer == address(0)) revert Errors.ZeroAddress();

		return implementation().predictDeterministicAddress(bytes32(bytes20(deployer)));
	}

	function setImplementation(address newImplementation) external authorized {
		emit ImplementationSet(implementation(), newImplementation);
		_implementation = newImplementation;
	}

	function implementation() public view returns (address) {
		return _implementation;
	}

	function isAuthorized(address account) internal view virtual override returns (bool) {
		return resolver.getACLManager().isFactoryAdmin(account);
	}
}
