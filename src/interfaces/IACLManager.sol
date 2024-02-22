// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IACLManager {
	function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

	function addFactoryAdmin(address account) external;

	function removeFactoryAdmin(address account) external;

	function isFactoryAdmin(address account) external view returns (bool);

	function addModuleListingAdmin(address account) external;

	function removeModuleListingAdmin(address account) external;

	function isModuleListingAdmin(address account) external view returns (bool);

	function addFeedListingAdmin(address account) external;

	function removeFeedListingAdmin(address account) external;

	function isFeedListingAdmin(address account) external view returns (bool);

	function addReserveListingAdmin(address account) external;

	function removeReserveListingAdmin(address account) external;

	function isReserveListingAdmin(address account) external view returns (bool);
}
