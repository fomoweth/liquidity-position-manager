// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILender} from "src/interfaces/ILender.sol";
import {ClientStorage} from "src/libraries/ClientStorage.sol";
import {Currency} from "src/types/Currency.sol";
import {StakingDispatcher} from "src/modules/adapters/StakingDispatcher.sol";

contract MockStakingDispatcher is StakingDispatcher {
	bytes32 constant CRV_ID = bytes32(bytes("CRV"));
	bytes32 constant CVX_ID = bytes32(bytes("CVX"));
	bytes32 constant UNI_V3_ID = bytes32(bytes("UNI-V3"));

	constructor(
		address _resolver,
		bytes32 _key,
		Currency _wrappedNative,
		address _owner
	) StakingDispatcher(_resolver, _key, _wrappedNative) {
		ClientStorage.configure(_owner);
	}

	function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
		return this.onERC721Received.selector;
	}

	function isAuthorized(address) internal view virtual override returns (bool) {
		return true;
	}

	function _checkDelegateCall() internal view virtual override {}

	function _noDelegateCall() internal view virtual override {}

	receive() external payable {}
}
