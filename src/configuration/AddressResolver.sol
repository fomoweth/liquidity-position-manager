// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {IACLManager} from "src/interfaces/IACLManager.sol";
import {IClientFactory} from "src/interfaces/IClientFactory.sol";
import {IFeedRegistry} from "src/interfaces/IFeedRegistry.sol";
import {ILendingDispatcher} from "src/interfaces/ILendingDispatcher.sol";
import {IStakingDispatcher} from "src/interfaces/IStakingDispatcher.sol";
import {IModuleRegistry} from "src/interfaces/IModuleRegistry.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

/// @title AddressResolver
/// @notice Main registry of protocol contracts
/// @dev modified from https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/configuration/PoolAddressesProvider.sol

contract AddressResolver is IAddressResolver, Ownable {
	mapping(bytes32 => address) internal _addresses;

	bytes32 internal constant ACL_ADMIN = keccak256(bytes("ACL_ADMIN"));
	bytes32 internal constant ACL_MANAGER = keccak256(bytes("ACL_MANAGER"));
	bytes32 internal constant CLIENT_FACTORY = keccak256(bytes("CLIENT_FACTORY"));
	bytes32 internal constant MODULE_REGISTRY = keccak256(bytes("MODULE_REGISTRY"));
	bytes32 internal constant FEED_REGISTRY = keccak256(bytes("FEED_REGISTRY"));
	bytes32 internal constant LENDING_DISPATCHER = keccak256(bytes("LENDING_DISPATCHER"));
	bytes32 internal constant STAKING_DISPATCHER = keccak256(bytes("STAKING_DISPATCHER"));

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

	function getClientFactory() external view returns (IClientFactory) {
		return IClientFactory(getAddress(CLIENT_FACTORY));
	}

	function setClientFactory(address newClientFactory) external onlyOwner {
		setAddress(CLIENT_FACTORY, newClientFactory);
	}

	function getModuleRegistry() external view returns (IModuleRegistry) {
		return IModuleRegistry(getAddress(MODULE_REGISTRY));
	}

	function setModuleRegistry(address newModuleRegistry) external onlyOwner {
		setAddress(MODULE_REGISTRY, newModuleRegistry);
	}

	function getFeedRegistry() external view returns (IFeedRegistry) {
		return IFeedRegistry(getAddress(FEED_REGISTRY));
	}

	function setFeedRegistry(address newFeedRegistry) external onlyOwner {
		setAddress(FEED_REGISTRY, newFeedRegistry);
	}

	function getLendingDispatcher() external view returns (ILendingDispatcher) {
		return ILendingDispatcher(getAddress(LENDING_DISPATCHER));
	}

	function setLendingDispatcher(address newLendingDispatcher) external onlyOwner {
		setAddress(LENDING_DISPATCHER, newLendingDispatcher);
	}

	function getStakingDispatcher() external view returns (IStakingDispatcher) {
		return IStakingDispatcher(getAddress(STAKING_DISPATCHER));
	}

	function setStakingDispatcher(address newStakingDispatcher) external onlyOwner {
		setAddress(STAKING_DISPATCHER, newStakingDispatcher);
	}

	function isZeroAddress(address target) internal pure returns (bool res) {
		assembly ("memory-safe") {
			res := iszero(target)
		}
	}
}
