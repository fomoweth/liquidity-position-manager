// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleRegistry} from "src/interfaces/IModuleRegistry.sol";
import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Authority} from "src/base/Authority.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

/// @title ModuleRegistry
/// @notice Registry of modules and signatures; modules can be mapped by its own signatures and vice versa

contract ModuleRegistry is IModuleRegistry, Authority, Initializable {
	using Arrays for bytes4[];

	mapping(bytes4 signature => address module) internal _modules;
	mapping(address module => bytes4[] signatures) internal _signatures;

	IAddressResolver internal resolver;

	constructor() {}

	function initialize(address _resolver) external initializer {
		resolver = IAddressResolver(_resolver);
	}

	function register(address module, bytes4[] calldata signatures) external authorized {
		uint256 length = signatures.length;
		uint256 i;

		while (i < length) {
			_modules[signatures.at(i)] = module;

			unchecked {
				i = i + 1;
			}
		}

		_signatures[module] = signatures;

		emit ModuleUpdated(module, signatures);
	}

	function deregister(address module) external authorized {
		bytes4[] memory cached = _signatures[module];
		uint256 length = cached.length;
		uint256 i;

		while (i < length) {
			delete _modules[cached.at(i)];

			unchecked {
				i = i + 1;
			}
		}

		delete _signatures[module];

		emit ModuleUpdated(module, cached);
	}

	function map(bytes4 signature) external view returns (address module) {
		if ((module = _modules[signature]) == address(0)) revert Errors.InvalidModule();
	}

	function map(address module) external view returns (bytes4[] memory signatures) {
		if ((signatures = _signatures[module]).length == 0) revert Errors.InvalidModule();
	}

	function isAuthorized(address account) internal view virtual override returns (bool) {
		return resolver.getACLManager().isModuleListingAdmin(account);
	}
}
