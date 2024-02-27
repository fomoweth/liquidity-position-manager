// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CompoundV2Adapter} from "src/modules/adapters/lenders/CompoundV2Adapter.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockCompoundV2Adapter is CompoundV2Adapter {
	using CurrencyLibrary for Currency;
	using WadRayMath for uint256;

	constructor(
		address _resolver,
		address _cTokenRegistry,
		bytes32 _protocol,
		address _comptroller,
		address _priceOracle,
		Currency _cNative,
		Currency _cEth,
		address _ethUsdFeed,
		Currency _wrappedNative,
		Currency _weth
	)
		CompoundV2Adapter(
			_resolver,
			_cTokenRegistry,
			_protocol,
			_comptroller,
			_priceOracle,
			_cNative,
			_cEth,
			_ethUsdFeed,
			_wrappedNative,
			_weth
		)
	{}

	function claimRewards() public payable {
		this.claimRewards("0x");
	}

	function getReserveIndices(Currency cToken) public view returns (uint256, uint256) {
		return accruedInterestIndices(cToken);
	}

	function getPendingRewards() public view returns (uint256) {
		return getPendingRewards(COMPTROLLER);
	}

	function getMarketsIn() public view returns (Currency[] memory) {
		return getMarketsIn(COMPTROLLER);
	}

	function getReservesList() public view returns (Currency[] memory) {
		return getAllMarkets(COMPTROLLER, true);
	}

	function getReservesList(bool filterDeprecated) public view returns (Currency[] memory) {
		return getAllMarkets(COMPTROLLER, filterDeprecated);
	}

	function getRewardAsset() public view returns (Currency) {
		return getCompAddress(COMPTROLLER);
	}

	function getSupplyBalance(Currency cToken) public view returns (uint256) {
		(uint256 exchangeRate, ) = accruedInterestIndices(cToken);

		return cToken.balanceOfSelf().wadMul(exchangeRate);
	}

	function getBorrowBalance(Currency cToken) public view returns (uint256) {
		(, uint256 borrowIndexNew) = accruedInterestIndices(cToken);

		return FullMath.mulDiv(borrowBalanceStored(cToken), borrowIndexNew, borrowIndex(cToken));
	}

	function getLtv(Currency cToken) public view returns (uint256) {
		return getLtv(COMPTROLLER, cToken);
	}

	function getPrice(Currency cToken) public view returns (uint256) {
		return getAssetPrice(cToken);
	}

	function checkMembership(Currency cToken) public view returns (bool accountMembership) {
		address comptroller = COMPTROLLER;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x929fe9a100000000000000000000000000000000000000000000000000000000) // checkMembership(address,address)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			accountMembership := mload(0x00)
		}
	}

	function _checkDelegateCall() internal view virtual override {}

	function _noDelegateCall() internal view virtual override {}

	receive() external payable {}
}
