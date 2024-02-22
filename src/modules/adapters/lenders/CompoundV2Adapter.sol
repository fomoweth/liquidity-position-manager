// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILender} from "src/interfaces/ILender.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseLender} from "./BaseLender.sol";

/// @title CompoundV2Adapter
/// @notice Provides the functionality of making calls to Compound-V2 contracts for the Client

contract CompoundV2Adapter is ILender, BaseLender {
	using BytesLib for bytes;
	using CurrencyLibrary for Currency;
	using FullMath for uint256;
	using PercentageMath for uint256;
	using WadRayMath for uint256;

	bytes4 internal constant CTOKEN_MINT_SELECTOR = 0xa0712d68;
	bytes4 internal constant CTOKEN_MINT_NATIVE_SELECTOR = 0x1249c58b;
	bytes4 internal constant CTOKEN_BORROW_SELECTOR = 0xc5ebeaec;
	bytes4 internal constant CTOKEN_REPAY_BORROW_SELECTOR = 0x0e752702;
	bytes4 internal constant CTOKEN_REPAY_BORROW_NATIVE_SELECTOR = 0x4e4d9fea;
	bytes4 internal constant CTOKEN_REDEEM_UNDERLYING_SELECTOR = 0x852a12e3;

	// accrualBlockNumber(), getCash(), totalBorrows(), totalReserves(), reserveFactorMantissa(), totalSupply(), borrowIndex(), exchangeRateStored()
	bytes32 internal constant SELECTORS = 0x6c540baf3b1d21a247bd37188f840ddd173b990418160dddaa5af0fd182df0f5;

	uint256 internal constant BLOCKS_PER_YEAR = 365 * 24 * 60 * 4;

	uint256 internal constant COMP_INITIAL_INDEX = 1e36;
	uint256 internal constant MAX_BORROW_RATE = 0.0005e16;

	address internal immutable COMPTROLLER;
	address internal immutable PRICE_ORACLE;

	Currency internal immutable cNATIVE;
	Currency internal immutable cETH;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _comptroller,
		address _priceOracle,
		Currency _cNative,
		Currency _cEth,
		Currency _wrappedNative,
		Currency _weth
	) BaseLender(_resolver, _protocol, USD, _wrappedNative, _weth) {
		COMPTROLLER = _comptroller;
		PRICE_ORACLE = _priceOracle;
		cNATIVE = _cNative;
		cETH = _cEth;
	}

	function supply(bytes calldata params) public payable returns (uint128, uint40) {
		(Currency cToken, Currency asset, uint256 amount) = decode(params);

		verifyReserve(cToken, asset, amount, true);

		bool isCNative = cToken == cNATIVE;

		if (!isCNative) {
			approveIfNeeded(asset, cToken.toAddress(), amount);

			invoke(cToken, isCNative, CTOKEN_MINT_SELECTOR, amount);
		} else {
			unwrapWETH(amount);

			invoke(cToken, isCNative, CTOKEN_MINT_NATIVE_SELECTOR, amount);
		}

		enterMarket(COMPTROLLER, cToken);

		return (exchangeRateStored(cToken), accrualBlockNumber(cToken));
	}

	function borrow(bytes calldata params) public payable returns (uint128, uint40) {
		(Currency cToken, Currency asset, uint256 amount) = decode(params);

		verifyReserve(cToken, asset, amount, false);

		invoke(cToken, false, CTOKEN_BORROW_SELECTOR, amount);

		if (cToken == cNATIVE) wrapETH(amount);

		return (borrowIndex(cToken), accrualBlockNumber(cToken));
	}

	function repay(bytes calldata params) public payable returns (uint128, uint40) {
		(Currency cToken, Currency asset, uint256 amount) = decode(params);

		verifyReserve(cToken, asset, amount, false);

		bool isCNative = cToken == cNATIVE;

		if (!isCNative) {
			approveIfNeeded(asset, cToken.toAddress(), amount);

			invoke(cToken, isCNative, CTOKEN_REPAY_BORROW_SELECTOR, amount);
		} else {
			unwrapWETH(amount);

			invoke(cToken, isCNative, CTOKEN_REPAY_BORROW_NATIVE_SELECTOR, amount);
		}

		return (borrowIndex(cToken), accrualBlockNumber(cToken));
	}

	function redeem(bytes calldata params) public payable returns (uint128, uint40) {
		(Currency cToken, Currency asset, uint256 amount) = decode(params);

		verifyReserve(cToken, asset, amount, true);

		invoke(cToken, false, CTOKEN_REDEEM_UNDERLYING_SELECTOR, amount);

		if (cToken == cNATIVE) wrapETH(amount);

		return (exchangeRateStored(cToken), accrualBlockNumber(cToken));
	}

	function invoke(Currency cToken, bool isCNative, bytes4 selector, uint256 value) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isCNative
			case 0x00 {
				mstore(ptr, selector)
				mstore(add(ptr, 0x04), value)

				if iszero(
					and(
						or(and(iszero(mload(0x00)), gt(returndatasize(), 0x1f)), iszero(returndatasize())),
						call(gas(), cToken, 0x00, ptr, 0x24, 0x00, 0x20)
					)
				) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				mstore(ptr, selector)

				if iszero(call(gas(), cToken, value, ptr, 0x04, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function enterMarket(bytes calldata params) public payable {
		enterMarket(COMPTROLLER, Currency.wrap(params.toAddress()));
	}

	function exitMarket(bytes calldata params) public payable {
		exitMarket(COMPTROLLER, Currency.wrap(params.toAddress()));
	}

	function enterMarket(address comptroller, Currency cToken) internal virtual {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x929fe9a100000000000000000000000000000000000000000000000000000000) // checkMembership(address,address)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			if iszero(mload(0x00)) {
				mstore(ptr, 0xc299823800000000000000000000000000000000000000000000000000000000) // enterMarkets(address[])
				mstore(add(ptr, 0x04), 0x20)
				mstore(add(ptr, 0x24), 0x01)
				mstore(add(ptr, 0x44), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

				if iszero(call(gas(), comptroller, 0x00, ptr, 0x64, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function exitMarket(address comptroller, Currency cToken) internal virtual {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xede4edd000000000000000000000000000000000000000000000000000000000) // exitMarket(address)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), comptroller, 0x00, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function claimRewards(bytes calldata) public payable {
		address comptroller = COMPTROLLER;

		if (getCompAddress(comptroller).isZero()) revert Errors.NotSupported();

		claimComp(comptroller, getMarketsIn(comptroller));
	}

	function claimComp(address comptroller, Currency[] memory cTokens) internal virtual {
		bytes memory markets = abi.encode(cTokens);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x1c3db2e000000000000000000000000000000000000000000000000000000000) // claimComp(address,address[])
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), 0x40)
			mstore(add(ptr, 0x44), div(mload(markets), 0x20))

			let offset := add(ptr, 0x64)
			let guard := add(offset, mload(markets))

			for {
				let i := add(markets, 0x20)
			} lt(offset, guard) {
				offset := add(offset, 0x20)
				i := add(i, 0x20)
			} {
				mstore(offset, mload(i))
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			if iszero(call(gas(), comptroller, 0x00, ptr, add(mload(markets), 0x64), 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getAccountLiquidity()
		external
		view
		returns (
			uint256 totalCollateral,
			uint256 totalLiability,
			uint256 availableLiquidity,
			uint256 healthFactor
		)
	{
		address comptroller = COMPTROLLER;
		address oracle = PRICE_ORACLE;

		uint256 ethPrice = getUnderlyingPrice(oracle, cETH, 18);

		Currency[] memory cTokens = getMarketsIn(comptroller);

		uint256 length = cTokens.length;
		uint256 i;

		while (i < length) {
			Currency cToken = cTokens[i];

			(uint256 cTokenBalance, uint256 borrowBalance, ) = getAccountSnapshot(cToken);

			uint8 unit = cTokenToUnderlying(cToken).decimals();

			uint256 price = getUnderlyingPrice(oracle, cToken, unit);

			uint256 derivedPrice = derivePrice(price, ethPrice, 8, 8, 18);

			(uint256 exchangeRate, uint256 index) = accruedInterestIndices(cToken);

			if (cTokenBalance != 0) {
				uint256 supplyBalance = cTokenBalance.wadMul(exchangeRate);
				uint256 collateralValue = FullMath.mulDiv(supplyBalance, derivedPrice, 10 ** unit);
				uint256 ltv = getLtv(comptroller, cToken);

				totalCollateral += collateralValue;
				availableLiquidity += collateralValue.percentMul(ltv);
			}

			if (borrowBalance != 0) {
				borrowBalance = FullMath.mulDiv(borrowBalance, index, borrowIndex(cToken));
				uint256 liabilityValue = FullMath.mulDiv(borrowBalance, derivedPrice, 10 ** unit);

				totalLiability += liabilityValue;
			}

			unchecked {
				i = i + 1;
			}
		}

		if (availableLiquidity != 0) {
			healthFactor = totalLiability != 0
				? PercentageMath.PERCENTAGE_FACTOR - (totalLiability.wadDiv(availableLiquidity) / 1e14)
				: PercentageMath.PERCENTAGE_FACTOR;

			availableLiquidity -= totalLiability;
		}
	}

	function getReserveData(bytes calldata params) external view returns (ReserveData memory reserveData) {
		address comptroller = COMPTROLLER;

		Currency cToken;

		assembly ("memory-safe") {
			cToken := calldataload(params.offset)
		}

		uint256 ltv = getLtv(comptroller, cToken);

		(uint256 exchangeRate, uint256 index) = accruedInterestIndices(cToken);

		return
			ReserveData({
				collateralMarket: cToken,
				borrowMarket: cToken,
				priceFeed: PRICE_ORACLE,
				price: getAssetPrice(cToken),
				ltv: ltv,
				supplyRate: getSupplyRate(cToken),
				borrowRate: getBorrowRate(cToken),
				supplyIndex: exchangeRate,
				borrowIndex: index,
				lastAccrualTime: accrualBlockNumber(cToken),
				isCollateral: ltv != 0,
				isBorrowable: true,
				isActive: !isMintPaused(comptroller, cToken) && !isBorrowPaused(comptroller, cToken)
			});
	}

	function getPendingRewards(bytes calldata) external view returns (uint256) {
		return getPendingRewards(COMPTROLLER);
	}

	function getPendingRewards(address comptroller) internal view virtual returns (uint256 pendingRewards) {
		Currency[] memory cTokens = getMarketsIn(comptroller);
		uint256 length = cTokens.length;
		uint256 i;

		if (length == 0) revert Errors.EmptyArray();

		pendingRewards = compAccrued(comptroller);

		while (i < length) {
			unchecked {
				pendingRewards += (supplyAccrued(comptroller, cTokens[i]) +
					borrowAccrued(comptroller, cTokens[i]));

				i = i + 1;
			}
		}
	}

	function supplyAccrued(address comptroller, Currency cToken) internal view returns (uint256 accrued) {
		uint256 supplyBalance = cToken.balanceOfSelf();

		if (supplyBalance != 0) {
			uint256 supplySpeed = compSupplySpeeds(comptroller, cToken);

			(uint256 supplyStateIndex, uint32 blockNum) = compSupplyState(comptroller, cToken);

			uint256 blockDelta;

			unchecked {
				blockDelta = blockNumber() - blockNum;
			}

			if (supplySpeed != 0 && supplyStateIndex != 0 && blockDelta != 0) {
				uint256 accruedComp = blockDelta.wadMul(supplySpeed);

				uint256 ratio = accruedComp.wadDiv(cToken.totalSupply());

				unchecked {
					supplyStateIndex += ratio;
				}

				uint256 supplierIndex = compSupplierIndex(comptroller, cToken);
				if (supplierIndex == 0) supplierIndex = COMP_INITIAL_INDEX;

				unchecked {
					uint256 deltaIndex = supplyStateIndex - supplierIndex;

					accrued = supplyBalance.wadMul(deltaIndex);
				}
			}
		}
	}

	function borrowAccrued(address comptroller, Currency cToken) internal view returns (uint256 accrued) {
		uint256 borrowBalance = borrowBalanceStored(cToken);

		if (borrowBalance != 0) {
			uint256 borrowSpeed = compBorrowSpeeds(comptroller, cToken);

			(uint256 borrowStateIndex, uint32 blockNum) = compBorrowState(comptroller, cToken);

			uint256 blockDelta;

			unchecked {
				blockDelta = blockNumber() - blockNum;
			}

			if (borrowSpeed != 0 && borrowStateIndex >= COMP_INITIAL_INDEX && blockDelta != 0) {
				uint256 marketBorrowIndex = borrowIndex(cToken);

				uint256 borrows = totalBorrows(cToken).wadDiv(marketBorrowIndex);

				uint256 accruedComp = blockDelta.wadMul(borrowSpeed);

				uint256 ratio = accruedComp.wadDiv(borrows);

				unchecked {
					borrowStateIndex += ratio;
				}

				uint256 borrowerIndex = compBorrowerIndex(comptroller, cToken);
				if (borrowerIndex == 0) borrowerIndex = COMP_INITIAL_INDEX;

				unchecked {
					uint256 deltaIndex = borrowStateIndex - borrowerIndex;

					accrued = borrowBalance.wadDiv(marketBorrowIndex).wadMul(deltaIndex);
				}
			}
		}
	}

	function compAccrued(address comptroller) internal view returns (uint256 accrued) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xcc7ebdc400000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			accrued := mload(0x00)
		}
	}

	function compSupplierIndex(
		address comptroller,
		Currency cToken
	) internal view returns (uint256 supplierIndex) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb21be7fd00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			supplierIndex := mload(0x00)
		}
	}

	function compSupplyState(
		address comptroller,
		Currency cToken
	) internal view returns (uint224 index, uint32 blockNum) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6b79c38d00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x40)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			index := mload(0x00)
			blockNum := mload(0x20)
		}
	}

	function compSupplySpeeds(
		address comptroller,
		Currency cToken
	) internal view returns (uint256 supplySpeed) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6aa875b500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			supplySpeed := mload(0x00)
		}
	}

	function compBorrowerIndex(
		address comptroller,
		Currency cToken
	) internal view returns (uint256 borrowerIndex) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xca0af04300000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			borrowerIndex := mload(0x00)
		}
	}

	function compBorrowState(
		address comptroller,
		Currency cToken
	) internal view returns (uint224 index, uint32 blockNum) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x8c57804e00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x40)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			index := mload(0x00)
			blockNum := mload(0x20)
		}
	}

	function compBorrowSpeeds(
		address comptroller,
		Currency cToken
	) internal view returns (uint256 borrowSpeed) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf4a433c000000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			borrowSpeed := mload(0x00)
		}
	}

	function getMarketsIn(address comptroller) internal view returns (Currency[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xabfceffc00000000000000000000000000000000000000000000000000000000) // getAssetsIn(address)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[]));
	}

	function getAllMarkets(
		address comptroller,
		bool filterDeprecated
	) internal view returns (Currency[] memory cTokens) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb0772d0b00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comptroller, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		Currency[] memory allCTokens = abi.decode(returndata, (Currency[]));

		if (!filterDeprecated) return allCTokens;

		cTokens = new Currency[](allCTokens.length);
		uint256 count;

		for (uint256 i; i < allCTokens.length; ++i) {
			if (!isDeprecated(comptroller, allCTokens[i])) {
				cTokens[count] = allCTokens[i];
				++count;
			}
		}

		assembly ("memory-safe") {
			mstore(cTokens, count)
		}
	}

	function cTokenToUnderlying(Currency cToken) internal view returns (Currency underlying) {
		if (cToken == cNATIVE) return WRAPPED_NATIVE;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6f307dc300000000000000000000000000000000000000000000000000000000) // underlying()

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			underlying := mload(0x00)
		}
	}

	function getCompAddress(address comptroller) internal view virtual returns (Currency comp) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x9d1b5a0a00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comptroller, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			comp := mload(0x00)
		}
	}

	function getAssetPrice(Currency cToken) internal view virtual returns (uint256) {
		if (cToken == cETH) return WadRayMath.WAD;

		address oracle = PRICE_ORACLE;
		uint256 ethPrice = getUnderlyingPrice(oracle, cETH, 18);
		uint256 price = getUnderlyingPrice(oracle, cToken, cTokenToUnderlying(cToken).decimals());

		return derivePrice(price, ethPrice, 8, 8, 18);
	}

	function getUnderlyingPrice(
		address oracle,
		Currency cToken,
		uint8 underlyingDecimals
	) internal view virtual returns (uint256 price) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xfc57d4df00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), oracle, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			price := div(mload(0x00), exp(10, sub(28, underlyingDecimals)))
		}
	}

	function accruedInterestIndices(
		Currency cToken
	) internal view returns (uint256 exchangeRate, uint256 index) {
		address irm = interestRateModel(cToken);

		assembly ("memory-safe") {
			function fetch(t, p, r) -> ret {
				if iszero(staticcall(gas(), t, p, 0x04, r, 0x20)) {
					revert(p, 0x04)
				}

				ret := mload(r)
			}

			let ptr := mload(0x40)
			let res := add(ptr, 0x20)
			let resPtr := add(res, 0x64)

			mstore(ptr, SELECTORS)

			// call cToken.accrualBlockNumber()
			if iszero(staticcall(gas(), cToken, ptr, 0x04, resPtr, 0x20)) {
				revert(ptr, 0x04)
			}

			let blockDelta := sub(number(), mload(resPtr))
			resPtr := add(resPtr, 0x20)

			switch iszero(blockDelta)
			case 0x00 {
				// call cToken.getCash()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x04), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x04), 0x04)
				}

				// let cash := fetch(cToken, add(ptr, 0x04), resPtr)

				let cash := mload(resPtr)
				resPtr := add(resPtr, 0x20)

				// call cToken.totalBorrows()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x08), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x08), 0x04)
				}

				let borrows := mload(resPtr)
				resPtr := add(resPtr, 0x20)

				// call cToken.totalReserves()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x0c), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x0c), 0x04)
				}

				let reserves := mload(resPtr)
				resPtr := add(resPtr, 0x20)

				// call cToken.reserveFactorMantissa()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x10), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x10), 0x04)
				}

				let reserveFactor := mload(resPtr)
				resPtr := add(resPtr, 0x20)

				// call cToken.totalSupply()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x14), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x14), 0x04)
				}

				let supplies := mload(resPtr)
				resPtr := add(resPtr, 0x20)

				// call cToken.borrowIndex()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x18), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x18), 0x04)
				}

				let indexPrior := mload(resPtr)
				resPtr := add(resPtr, 0x20)

				mstore(res, 0x15f2405300000000000000000000000000000000000000000000000000000000) // irm.getBorrowRate(uint256,uint256,uint256)
				mstore(add(res, 0x04), cash)
				mstore(add(res, 0x24), borrows)
				mstore(add(res, 0x44), reserves)

				if iszero(staticcall(gas(), irm, res, 0x64, resPtr, 0x40)) {
					revert(res, 0x04)
				}

				let borrowRate

				switch returndatasize()
				case 0x20 {
					borrowRate := mload(resPtr)
				}
				case 0x40 {
					borrowRate := mload(add(resPtr, 0x20))
				}

				if gt(borrowRate, MAX_BORROW_RATE) {
					invalid()
				}

				let wad := exp(10, 18)
				let interestFactor := mul(borrowRate, blockDelta)
				let interestAccumulated := div(mul(interestFactor, borrows), wad)

				borrows := add(borrows, interestAccumulated)
				reserves := add(reserves, div(mul(reserveFactor, interestAccumulated), wad))
				exchangeRate := div(mul(sub(add(cash, borrows), reserves), wad), supplies)
				index := add(indexPrior, div(mul(interestFactor, indexPrior), wad))
			}
			default {
				// call cToken.borrowIndex()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x18), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x18), 0x04)
				}

				index := mload(resPtr)
				resPtr := add(resPtr, 0x20)

				// call cToken.exchangeRateStored()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x1c), 0x04, resPtr, 0x20)) {
					revert(add(ptr, 0x1c), 0x04)
				}

				exchangeRate := mload(resPtr)
			}
		}
	}

	function getAccountSnapshot(
		Currency cToken
	) internal view returns (uint256 cTokenBalance, uint256 borrowBalance, uint256 exchangeRate) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0xc37f68e200000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), cToken, ptr, 0x24, res, 0x80)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			cTokenBalance := mload(add(res, 0x20))
			borrowBalance := mload(add(res, 0x40))
			exchangeRate := mload(add(res, 0x60))
		}
	}

	function getLtv(address comptroller, Currency cToken) internal view virtual returns (uint256 ltv) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x8e8f294b00000000000000000000000000000000000000000000000000000000) // markets(address)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, add(ptr, 0x24), 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			ltv := div(mload(add(ptr, 0x44)), exp(10, 14))
		}
	}

	function getSupplyRate(Currency cToken) internal view returns (uint256 supplyRate) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xae9d70b000000000000000000000000000000000000000000000000000000000) // supplyRatePerBlock()

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			supplyRate := mul(mload(0x00), BLOCKS_PER_YEAR)
		}
	}

	function getBorrowRate(Currency cToken) internal view returns (uint256 borrowRate) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf8f9da2800000000000000000000000000000000000000000000000000000000) // borrowRatePerBlock()

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			borrowRate := mul(mload(0x00), BLOCKS_PER_YEAR)
		}
	}

	function borrowBalanceStored(Currency cToken) internal view returns (uint256 borrowBalance) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x95dd919300000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), cToken, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			borrowBalance := mload(0x00)
		}
	}

	function totalBorrows(Currency cToken) internal view returns (uint256 borrows) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x47bd371800000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			borrows := mload(0x00)
		}
	}

	function borrowIndex(Currency cToken) internal view returns (uint128 index) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xaa5af0fd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			index := mload(0x00)
		}
	}

	function exchangeRateStored(Currency cToken) internal view returns (uint128 exchangeRate) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x182df0f500000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			exchangeRate := mload(0x00)
		}
	}

	function accrualBlockNumber(Currency cToken) internal view returns (uint40 blockNum) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6c540baf00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			blockNum := mod(mload(0x00), exp(0x02, 0x28))
		}
	}

	function interestRateModel(Currency cToken) internal view returns (address irm) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf3fdb15a00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			irm := mload(0x00)
		}
	}

	function isDeprecated(
		address comptroller,
		Currency cToken
	) internal view virtual returns (bool deprecated) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x94543c1500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			deprecated := mload(0x00)
		}
	}

	function isMintPaused(address comptroller, Currency cToken) internal view returns (bool paused) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x731f0c2b00000000000000000000000000000000000000000000000000000000) // mintGuardianPaused(address)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			paused := mload(0x00)
		}
	}

	function isBorrowPaused(address comptroller, Currency cToken) internal view returns (bool paused) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6d154ea500000000000000000000000000000000000000000000000000000000) // borrowGuardianPaused(address)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			paused := mload(0x00)
		}
	}

	function _verifyReserve(
		Currency cToken,
		Currency asset,
		uint256 amount,
		bool useAsCollateral
	) internal view virtual override returns (ReserveError) {
		if (cToken.isZero() || asset.isZero()) return ReserveError.ZeroAddress;
		if (amount == 0) return ReserveError.ZeroAmount;
		if (cTokenToUnderlying(cToken) != asset) return ReserveError.NotSupported;

		address comptroller = COMPTROLLER;

		if (useAsCollateral && getLtv(comptroller, cToken) == 0) return ReserveError.NotCollateral;

		if (isMintPaused(comptroller, cToken) || isBorrowPaused(comptroller, cToken)) {
			return ReserveError.NotActive;
		}

		return ReserveError.NoError;
	}

	function decode(
		bytes calldata params
	) internal pure returns (Currency cToken, Currency asset, uint256 amount) {
		assembly ("memory-safe") {
			cToken := calldataload(params.offset)
			asset := calldataload(add(params.offset, 0x20))
			amount := calldataload(add(params.offset, 0x40))
		}
	}
}
