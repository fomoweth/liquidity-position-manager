// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILender} from "src/interfaces/ILender.sol";
import {ClientStorage} from "src/libraries/ClientStorage.sol";
import {Currency} from "src/types/Currency.sol";
import {LendingDispatcher} from "src/modules/adapters/LendingDispatcher.sol";

contract MockLendingDispatcher is LendingDispatcher {
	bytes32 constant AAVE_V2_ID = bytes32(bytes("AAVE-V2"));
	bytes32 constant AAVE_V3_ID = bytes32(bytes("AAVE-V3"));
	bytes32 constant COMP_V2_ID = bytes32(bytes("COMP-V2"));
	bytes32 constant COMP_V3_ID = bytes32(bytes("COMP-V3"));

	constructor(
		address _resolver,
		bytes32 _key,
		Currency _wrappedNative,
		address _owner
	) LendingDispatcher(_resolver, _key, _wrappedNative) {
		ClientStorage.configure(_owner);
	}

	function getSupplyBalance(bytes32 key, Currency market, Currency asset) public view returns (uint256) {
		return
			this.getSupplyBalance(
				key,
				key == COMP_V3_ID ? abi.encode(abi.encode(market, asset, address(this))) : key == COMP_V2_ID
					? abi.encode(abi.encode(market, address(this)))
					: abi.encode(abi.encode(asset, address(this)))
			);
	}

	function getBorrowBalance(bytes32 key, Currency market, Currency asset) public view returns (uint256) {
		return
			this.getBorrowBalance(
				key,
				(key == COMP_V3_ID || key == COMP_V2_ID)
					? abi.encode(abi.encode(market, address(this)))
					: abi.encode(abi.encode(asset, address(this)))
			);
	}

	function getReserveData(
		bytes32 key,
		Currency market,
		Currency asset
	) external view returns (ILender.ReserveData memory reserveData) {
		return
			this.getReserveData(
				key,
				key == COMP_V3_ID ? abi.encode(abi.encode(market, asset)) : key == COMP_V2_ID
					? abi.encode(abi.encode(market))
					: abi.encode(abi.encode(asset))
			);
	}

	function getReserveIndices(
		bytes32 key,
		Currency market,
		Currency asset
	) external view returns (uint256 supplyIndex, uint256 borrowIndex, uint256 lastAccrualTime) {
		return
			this.getReserveIndices(
				key,
				key == COMP_V3_ID ? abi.encode(abi.encode(market, asset)) : key == COMP_V2_ID
					? abi.encode(abi.encode(market))
					: abi.encode(abi.encode(asset))
			);
	}

	function getAssetPrice(bytes32 key, Currency market, Currency asset) public view returns (uint256) {
		return
			this.getAssetPrice(
				key,
				key == COMP_V3_ID ? abi.encode(abi.encode(market, asset)) : key == COMP_V2_ID
					? abi.encode(abi.encode(market))
					: abi.encode(abi.encode(asset))
			);
	}

	function getLtv(bytes32 key, Currency market, Currency asset) public view returns (uint256) {
		return
			this.getLtv(
				key,
				key == COMP_V3_ID ? abi.encode(abi.encode(market, asset)) : key == COMP_V2_ID
					? abi.encode(abi.encode(market))
					: abi.encode(abi.encode(asset))
			);
	}

	function isAuthorized(address) internal view virtual override returns (bool) {
		return true;
	}

	function _checkDelegateCall() internal view virtual override {}

	function _noDelegateCall() internal view virtual override {}

	receive() external payable {}
}
