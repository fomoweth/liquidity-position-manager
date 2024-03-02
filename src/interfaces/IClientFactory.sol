// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IClientFactory {
	event ImplementationSet(address indexed oldImplementation, address indexed newImplementation);

	function deploy() external payable returns (address client);

	function computeAddress(address deployer) external view returns (address client);

	function setImplementation(address newImplementation) external;

	function implementation() external view returns (address implementation);
}
