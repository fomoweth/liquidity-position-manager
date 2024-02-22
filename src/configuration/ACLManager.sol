// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IACLManager} from "src/interfaces/IACLManager.sol";
import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

/// @title ACLManager
/// @notice Registry of system roles and permissions
/// @dev modified from https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/configuration/ACLManager.sol

contract ACLManager is IACLManager, AccessControl, Initializable {
	bytes32 internal constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN");
	bytes32 internal constant FEED_LISTING_ADMIN_ROLE = keccak256(bytes("FEED_LISTING_ADMIN"));
	bytes32 internal constant MODULE_LISTING_ADMIN_ROLE = keccak256("MODULE_LISTING_ADMIN");
	bytes32 internal constant RESERVE_LISTING_ADMIN_ROLE = keccak256("RESERVE_LISTING_ADMIN");

	IAddressResolver internal resolver;

	function initialize(address _resolver) external initializer {
		_grantRole(DEFAULT_ADMIN_ROLE, (resolver = IAddressResolver(_resolver)).getACLAdmin());
	}

	function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_setRoleAdmin(role, adminRole);
	}

	function addFactoryAdmin(address account) external {
		grantRole(FACTORY_ADMIN_ROLE, account);
	}

	function removeFactoryAdmin(address account) external {
		revokeRole(FACTORY_ADMIN_ROLE, account);
	}

	function isFactoryAdmin(address account) external view returns (bool) {
		return hasRole(FACTORY_ADMIN_ROLE, account);
	}

	function addModuleListingAdmin(address account) external {
		grantRole(MODULE_LISTING_ADMIN_ROLE, account);
	}

	function removeModuleListingAdmin(address account) external {
		revokeRole(MODULE_LISTING_ADMIN_ROLE, account);
	}

	function isModuleListingAdmin(address account) external view returns (bool) {
		return hasRole(MODULE_LISTING_ADMIN_ROLE, account);
	}

	function addFeedListingAdmin(address account) external {
		grantRole(FEED_LISTING_ADMIN_ROLE, account);
	}

	function removeFeedListingAdmin(address account) external {
		revokeRole(FEED_LISTING_ADMIN_ROLE, account);
	}

	function isFeedListingAdmin(address account) external view returns (bool) {
		return hasRole(FEED_LISTING_ADMIN_ROLE, account);
	}

	function addReserveListingAdmin(address account) external {
		grantRole(RESERVE_LISTING_ADMIN_ROLE, account);
	}

	function removeReserveListingAdmin(address account) external {
		revokeRole(RESERVE_LISTING_ADMIN_ROLE, account);
	}

	function isReserveListingAdmin(address account) external view returns (bool) {
		return hasRole(RESERVE_LISTING_ADMIN_ROLE, account);
	}
}
