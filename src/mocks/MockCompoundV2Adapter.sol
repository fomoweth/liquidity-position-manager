// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CompoundV2Adapter} from "src/modules/adapters/lenders/CompoundV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";

contract MockCompoundV2Adapter is CompoundV2Adapter {
	using CurrencyLibrary for Currency;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _comptroller,
		address _priceOracle,
		Currency _cNative,
		Currency _cEth,
		Currency _wrappedNative,
		Currency _weth
	)
		CompoundV2Adapter(
			_resolver,
			_protocol,
			_comptroller,
			_priceOracle,
			_cNative,
			_cEth,
			_wrappedNative,
			_weth
		)
	{}

	function supply(
		Currency cToken,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (uint128 reserveIndex, uint40 accrualBlockNumber, uint256 balancePrior, uint256 balanceNew)
	{
		balancePrior = cToken.balanceOfSelf();

		(reserveIndex, accrualBlockNumber) = this.supply(abi.encode(cToken, asset, amount));

		balanceNew = cToken.balanceOfSelf();
	}

	function borrow(
		Currency cToken,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (uint128 reserveIndex, uint40 accrualBlockNumber, uint256 balancePrior, uint256 balanceNew)
	{
		balancePrior = cToken.balanceOfSelf();

		(reserveIndex, accrualBlockNumber) = this.borrow(abi.encode(cToken, asset, amount));

		balanceNew = cToken.balanceOfSelf();
	}

	function repay(
		Currency cToken,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (uint128 reserveIndex, uint40 accrualBlockNumber, uint256 balancePrior, uint256 balanceNew)
	{
		balancePrior = cToken.balanceOfSelf();

		(reserveIndex, accrualBlockNumber) = this.repay(abi.encode(cToken, asset, amount));

		balanceNew = cToken.balanceOfSelf();
	}

	function redeem(
		Currency cToken,
		Currency asset,
		uint256 amount
	)
		public
		payable
		returns (uint128 reserveIndex, uint40 accrualBlockNumber, uint256 balancePrior, uint256 balanceNew)
	{
		balancePrior = cToken.balanceOfSelf();

		(reserveIndex, accrualBlockNumber) = this.redeem(abi.encode(cToken, asset, amount));

		balanceNew = cToken.balanceOfSelf();
	}

	function enterMarket(Currency cToken) public payable {
		this.enterMarket(abi.encode(cToken));
	}

	function exitMarket(Currency cToken) public payable {
		this.exitMarket(abi.encode(cToken));
	}

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

	function getUnderlyingPrice(Currency cToken) public view returns (uint256) {
		if (cToken == cNATIVE) return getUnderlyingPrice(PRICE_ORACLE, cToken, 18);

		return getUnderlyingPrice(PRICE_ORACLE, cToken, cTokenToUnderlying(cToken).decimals());
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

	receive() external payable {}
}
