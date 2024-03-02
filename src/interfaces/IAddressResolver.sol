// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IACLManager} from "./IACLManager.sol";
import {IClientFactory} from "./IClientFactory.sol";
import {IFeedRegistry} from "./IFeedRegistry.sol";
import {IModuleRegistry} from "./IModuleRegistry.sol";

interface IAddressResolver {
	event AddressSet(bytes32 indexed key, address indexed oldAddress, address indexed newAddress);

	error AddressNotSet();

	function getAddress(bytes32 key) external view returns (address);

	function setAddress(bytes32 key, address newAddress) external;

	function getACLAdmin() external view returns (address);

	function setACLAdmin(address newACLAdmin) external;

	function getACLManager() external view returns (IACLManager);

	function setACLManager(address newACLManager) external;

	function getClientFactory() external view returns (IClientFactory);

	function setClientFactory(address newClientFactory) external;

	function getModuleRegistry() external view returns (IModuleRegistry);

	function setModuleRegistry(address newModuleRegistry) external;

	function getFeedRegistry() external view returns (IFeedRegistry);

	function setFeedRegistry(address newFeedRegistry) external;
}
