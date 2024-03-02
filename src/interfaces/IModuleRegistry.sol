// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IModuleRegistry {
	event ModuleUpdated(address indexed module, bytes4[] selectors);

	enum Command {
		Add,
		Remove,
		Replace
	}

	function register(address module, bytes4[] calldata signatures) external;

	function deregister(address module) external;

	function map(bytes4 selector) external view returns (address);

	function map(address module) external view returns (bytes4[] memory);
}
