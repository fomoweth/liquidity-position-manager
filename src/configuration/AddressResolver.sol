// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {IACLManager} from "src/interfaces/IACLManager.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

/// @title AddressResolver
/// @notice Main registry of protocol contracts
/// @dev modified from https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/configuration/PoolAddressesProvider.sol

contract AddressResolver is IAddressResolver, Ownable {
	mapping(bytes32 => address) internal _addresses;

	bytes32 internal constant ACL_ADMIN = keccak256(bytes("ACL_ADMIN"));
	bytes32 internal constant ACL_MANAGER = keccak256(bytes("ACL_MANAGER"));

	constructor(address initialOwner) Ownable(initialOwner) {}

	function getAddress(bytes32 key) public view returns (address target) {
		if (isZeroAddress(target = _addresses[key])) revert AddressNotSet();
	}

	function setAddress(bytes32 key, address newAddress) public onlyOwner {
		emit AddressSet(key, _addresses[key], newAddress);
		_addresses[key] = newAddress;
	}

	function getACLAdmin() external view returns (address) {
		return getAddress(ACL_ADMIN);
	}

	function setACLAdmin(address newACLAdmin) external onlyOwner {
		setAddress(ACL_ADMIN, newACLAdmin);
	}

	function getACLManager() external view returns (IACLManager) {
		return IACLManager(getAddress(ACL_MANAGER));
	}

	function setACLManager(address newACLManager) external onlyOwner {
		setAddress(ACL_MANAGER, newACLManager);
	}

	function isZeroAddress(address target) internal pure returns (bool res) {
		assembly ("memory-safe") {
			res := iszero(target)
		}
	}
}
