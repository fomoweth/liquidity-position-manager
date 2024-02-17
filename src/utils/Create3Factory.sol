// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICreate3Factory} from "src/interfaces/ICreate3Factory.sol";
import {Create3} from "src/libraries/Create3.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";
import {Context} from "@openzeppelin/utils/Context.sol";

/// @title Create3Factory
/// @dev Deploys contracts to deterministic addresses via CREATE3

contract Create3Factory is ICreate3Factory, Context {
	function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address) {
		return Create3.create3(hashSalt(salt, _msgSender()), creationCode);
	}

	function computeAddress(bytes32 salt, address deployer) external view returns (address) {
		return Create3.addressOf(hashSalt(salt, deployer));
	}

	function hashSalt(bytes32 salt, address account) internal pure returns (bytes32 digest) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, shl(0x60, account))
			mstore(add(ptr, 0x14), salt)

			digest := keccak256(ptr, 0x34)
		}
	}
}
