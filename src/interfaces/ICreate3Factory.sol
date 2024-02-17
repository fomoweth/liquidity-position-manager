// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICreate3Factory {
	function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address);

	function computeAddress(bytes32 salt, address deployer) external view returns (address);
}
