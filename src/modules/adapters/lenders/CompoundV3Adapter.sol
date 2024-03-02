// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILender} from "src/interfaces/ILender.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseLender} from "./BaseLender.sol";

/// @title CompoundV3Adapter
/// @notice Provides the functionality of making calls to Compound-V3 contracts for the Client

contract CompoundV3Adapter is ILender, BaseLender {
	using BytesLib for bytes;
	using CurrencyLibrary for Currency;
	using FullMath for uint256;
	using PercentageMath for uint256;
	using SafeCast for uint256;
	using WadRayMath for uint256;

	struct Configuration {
		address governor;
		address pauseGuardian;
		Currency baseToken;
		address baseTokenPriceFeed;
		Currency extensionDelegate;
		uint64 supplyKink;
		uint64 supplyPerYearInterestRateSlopeLow;
		uint64 supplyPerYearInterestRateSlopeHigh;
		uint64 supplyPerYearInterestRateBase;
		uint64 borrowKink;
		uint64 borrowPerYearInterestRateSlopeLow;
		uint64 borrowPerYearInterestRateSlopeHigh;
		uint64 borrowPerYearInterestRateBase;
		uint64 storeFrontPriceFactor;
		uint64 trackingIndexScale;
		uint64 baseTrackingSupplySpeed;
		uint64 baseTrackingBorrowSpeed;
		uint104 baseMinForRewards;
		uint104 baseBorrowMin;
		uint104 targetReserves;
		AssetConfig[] assetConfigs;
	}

	struct AssetConfig {
		Currency asset;
		address priceFeed;
		uint8 decimals;
		uint64 borrowCollateralFactor;
		uint64 liquidateCollateralFactor;
		uint64 liquidationFactor;
		uint128 supplyCap;
	}

	struct AssetInfo {
		uint8 offset;
		Currency asset;
		address priceFeed;
		uint64 scale;
		uint64 borrowCollateralFactor;
		uint64 liquidateCollateralFactor;
		uint64 liquidationFactor;
		uint128 supplyCap;
	}

	bytes4 internal constant COMET_SUPPLY_SELECTOR = 0xf2b9fdb8;
	bytes4 internal constant COMET_WITHDRAW_SELECTOR = 0xf3fef3a3;

	uint8 internal constant PRICE_FEED_DECIMALS = 8;
	uint64 internal constant PRICE_SCALE = uint64(10 ** PRICE_FEED_DECIMALS);
	uint64 internal constant FACTOR_SCALE = 1e18;
	uint64 internal constant DESCALE = 1e14;
	uint64 internal constant BASE_ACCRUAL_SCALE = 1e6;
	uint64 internal constant BASE_INDEX_SCALE = 1e15;

	uint16 internal constant DAYS_PER_YEAR = 365;
	uint64 internal constant SECONDS_PER_YEAR = 31_536_000;

	address internal immutable CONFIGURATOR;
	address internal immutable REWARDS;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _configurator,
		address _rewards,
		address _ethUsdFeed,
		Currency _wrappedNative,
		Currency _weth
	) BaseLender(_resolver, _protocol, USD, _ethUsdFeed, _wrappedNative, _weth) {
		CONFIGURATOR = _configurator;
		REWARDS = _rewards;
	}

	function supply(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 reserveIndex, uint40 lastAccruedTimestamp)
	{
		(Currency comet, Currency asset, uint256 amount) = decode(params);

		verifyReserve(comet, asset, amount, true);

		approveIfNeeded(asset, comet.toAddress(), amount);

		invoke(comet, COMET_SUPPLY_SELECTOR, asset, amount);

		(reserveIndex, , , , , , lastAccruedTimestamp, ) = totalsBasic(comet);
	}

	function borrow(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 reserveIndex, uint40 lastAccruedTimestamp)
	{
		(Currency comet, Currency asset, uint256 amount) = decode(params);

		verifyReserve(comet, asset, amount, false);

		invoke(comet, COMET_WITHDRAW_SELECTOR, asset, amount);

		(, reserveIndex, , , , , lastAccruedTimestamp, ) = totalsBasic(comet);
	}

	function repay(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 reserveIndex, uint40 lastAccruedTimestamp)
	{
		(Currency comet, Currency asset, uint256 amount) = decode(params);

		verifyReserve(comet, asset, amount, false);

		approveIfNeeded(asset, comet.toAddress(), amount);

		invoke(comet, COMET_SUPPLY_SELECTOR, asset, amount);

		(, reserveIndex, , , , , lastAccruedTimestamp, ) = totalsBasic(comet);
	}

	function redeem(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 reserveIndex, uint40 lastAccruedTimestamp)
	{
		(Currency comet, Currency asset, uint256 amount) = decode(params);

		verifyReserve(comet, asset, amount, true);

		invoke(comet, COMET_WITHDRAW_SELECTOR, asset, amount);

		(reserveIndex, , , , , , lastAccruedTimestamp, ) = totalsBasic(comet);
	}

	function invoke(Currency comet, bytes4 selector, Currency asset, uint256 amount) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, selector)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)

			if iszero(call(gas(), comet, 0x00, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function enterMarket(bytes calldata) public payable authorized checkDelegateCall {
		revert Errors.NotSupported();
	}

	function exitMarket(bytes calldata) public payable authorized checkDelegateCall {
		revert Errors.NotSupported();
	}

	function claimRewards(bytes calldata params) public payable authorized checkDelegateCall {
		address rewards = REWARDS;
		address comet = params.toAddress();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb7034f7e00000000000000000000000000000000000000000000000000000000) // claim(address,address,bool)
			mstore(add(ptr, 0x04), and(comet, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), and(0x01, 0xff))

			if iszero(call(gas(), rewards, 0x00, ptr, 0x64, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getAccountLiquidity(
		bytes calldata params
	)
		external
		view
		returns (
			uint256 totalCollateral,
			uint256 totalLiability,
			uint256 availableLiquidity,
			uint256 healthFactor
		)
	{
		Currency comet;
		address account;

		assembly ("memory-safe") {
			comet := calldataload(params.offset)
			account := calldataload(add(params.offset, 0x20))
		}

		(int104 principal, , , uint16 assetsIn, ) = userBasic(comet, account);

		(uint64 baseSupplyIndex, uint64 baseBorrowIndex, , , , , , ) = totalsBasic(comet);

		uint256 basePrice = getPrice(comet, baseTokenPriceFeed(comet));

		if (principal > 0) {
			totalCollateral = FullMath.mulDiv(uint104(principal), baseSupplyIndex, BASE_INDEX_SCALE).mulDiv(
				basePrice,
				PRICE_SCALE
			);
		} else if (principal < 0) {
			totalLiability = FullMath.mulDiv(uint104(-principal), baseBorrowIndex, BASE_INDEX_SCALE).mulDiv(
				basePrice,
				PRICE_SCALE
			);
		}

		uint8 length = numAssets(comet);
		uint8 i;

		while (i < length) {
			if (getFlag(assetsIn, i)) {
				(
					Currency asset,
					address priceFeed,
					uint64 scale,
					uint64 borrowCollateralFactor,
					,
					,

				) = getAssetInfo(comet, i);

				uint256 collateralBalance = collateralBalanceOf(comet, asset, account);

				if (collateralBalance != 0) {
					uint256 collateralValue = collateralBalance.mulDiv(getPrice(comet, priceFeed), scale);

					unchecked {
						totalCollateral += collateralValue;

						availableLiquidity += collateralValue.wadMul(borrowCollateralFactor);
					}
				}
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

		if (baseToken(comet) != WETH) {
			uint256 ethPrice = getETHPrice();

			totalCollateral = derivePrice(totalCollateral, ethPrice, 8, 8, 18);
			totalLiability = derivePrice(totalLiability, ethPrice, 8, 8, 18);
			availableLiquidity = derivePrice(availableLiquidity, ethPrice, 8, 8, 18);
		}
	}

	function getSupplyBalance(bytes calldata params) external view returns (uint256) {
		Currency comet;
		Currency asset;
		address account;

		assembly ("memory-safe") {
			comet := calldataload(params.offset)
			asset := calldataload(add(params.offset, 0x20))
			account := calldataload(add(params.offset, 0x40))
		}

		return collateralBalanceOf(comet, asset, account);
	}

	function getBorrowBalance(bytes calldata params) external view returns (uint256) {
		Currency comet;
		address account;

		assembly ("memory-safe") {
			comet := calldataload(params.offset)
			account := calldataload(add(params.offset, 0x20))
		}

		return borrowBalanceOf(comet, account);
	}

	function getReserveData(bytes calldata params) external view returns (ReserveData memory reserveData) {
		Currency comet;
		Currency asset;

		assembly ("memory-safe") {
			comet := calldataload(params.offset)
			asset := calldataload(add(params.offset, 0x20))
		}

		reserveData.collateralMarket = comet;
		reserveData.borrowMarket = comet;

		if (!isBaseAsset(comet, asset)) {
			(, reserveData.priceFeed, , reserveData.ltv, , , ) = getAssetInfoByAddress(comet, asset);
		} else {
			reserveData.priceFeed = baseTokenPriceFeed(comet);

			(
				uint64 baseSupplyIndex,
				uint64 baseBorrowIndex,
				,
				,
				uint104 totalSupplyBase,
				uint104 totalBorrowBase,
				uint40 lastAccrualTime,

			) = totalsBasic(comet);

			uint256 utilization = computeUtilization(
				baseSupplyIndex,
				baseBorrowIndex,
				totalSupplyBase,
				totalBorrowBase
			);

			reserveData.supplyIndex = baseSupplyIndex;
			reserveData.borrowIndex = baseBorrowIndex;
			reserveData.lastAccrualTime = lastAccrualTime;
			reserveData.supplyRate = getSupplyRate(comet, utilization);
			reserveData.borrowRate = getBorrowRate(comet, utilization);
		}

		reserveData.price = getPrice(comet, reserveData.priceFeed);
	}

	function getReserveIndices(
		bytes calldata params
	) external view returns (uint256 supplyIndex, uint256 borrowIndex, uint256 lastAccrualTime) {
		return getReserveIndices(Currency.wrap(params.toAddress()));
	}

	function getLtv(bytes calldata params) external view returns (uint256 ltv) {
		Currency comet;
		Currency asset;

		assembly ("memory-safe") {
			comet := calldataload(params.offset)
			asset := calldataload(add(params.offset, 0x20))
		}

		if (!isBaseAsset(comet, asset)) {
			(, , , ltv, , , ) = getAssetInfoByAddress(comet, asset);
		}
	}

	function getAssetPrice(bytes calldata params) external view returns (uint256) {
		Currency comet;
		Currency asset;

		assembly ("memory-safe") {
			comet := calldataload(params.offset)
			asset := calldataload(add(params.offset, 0x20))
		}

		return getAssetPrice(comet, asset);
	}

	function getMarketsIn(Currency comet, address account) internal view returns (Currency[] memory assets) {
		(int104 principal, , , uint16 assetsIn, ) = userBasic(comet, account);

		AssetConfig[] memory configs = getConfiguration(CONFIGURATOR, comet).assetConfigs;
		uint256 length = configs.length;
		uint256 count;
		uint8 i;

		unchecked {
			assets = new Currency[](length + 1);

			while (i < length) {
				if (getFlag(assetsIn, i)) {
					assets[count] = configs[i].asset;
					count = count + 1;
				}

				i = i + 1;
			}

			if (principal != 0) {
				assets[count] = baseToken(comet);
				count = count + 1;
			}
		}

		assembly ("memory-safe") {
			mstore(assets, count)
		}
	}

	function getReserveIndices(
		Currency comet
	) internal view returns (uint64 baseSupplyIndex, uint64 baseBorrowIndex, uint40 lastAccrualTime) {
		uint104 totalSupplyBase;
		uint104 totalBorrowBase;

		(
			baseSupplyIndex,
			baseBorrowIndex,
			,
			,
			totalSupplyBase,
			totalBorrowBase,
			lastAccrualTime,

		) = totalsBasic(comet);

		unchecked {
			uint40 timeElapsed = blockTimestamp() - lastAccrualTime;

			if (timeElapsed != 0) {
				uint256 utilization = computeUtilization(
					baseSupplyIndex,
					baseBorrowIndex,
					totalSupplyBase,
					totalBorrowBase
				);

				baseSupplyIndex += FullMath
					.mulDiv(baseSupplyIndex, getSupplyRate(comet, utilization) * timeElapsed, FACTOR_SCALE)
					.toUint64();

				baseBorrowIndex += FullMath
					.mulDiv(baseBorrowIndex, getBorrowRate(comet, utilization) * timeElapsed, FACTOR_SCALE)
					.toUint64();
			}
		}
	}

	function totalsBasic(
		Currency comet
	)
		internal
		view
		returns (
			uint64 baseSupplyIndex,
			uint64 baseBorrowIndex,
			uint64 trackingSupplyIndex,
			uint64 trackingBorrowIndex,
			uint104 totalSupplyBase,
			uint104 totalBorrowBase,
			uint40 lastAccrualTime,
			uint8 pauseFlags
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x04)

			mstore(ptr, 0xb9f0baf700000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comet, ptr, 0x04, res, 0x100)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			baseSupplyIndex := mload(res)
			baseBorrowIndex := mload(add(res, 0x20))
			trackingSupplyIndex := mload(add(res, 0x40))
			trackingBorrowIndex := mload(add(res, 0x60))
			totalSupplyBase := mload(add(res, 0x80))
			totalBorrowBase := mload(add(res, 0xa0))
			lastAccrualTime := mload(add(res, 0xc0))
			pauseFlags := mload(add(res, 0xe0))
		}
	}

	function userBasic(
		Currency comet,
		address account
	)
		internal
		view
		returns (
			int104 principal,
			uint64 baseTrackingIndex,
			uint64 baseTrackingAccrued,
			uint16 assetsIn,
			uint8 reserved
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0xdc4abafd00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comet, ptr, 0x24, res, 0xa0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			principal := mload(res)
			baseTrackingIndex := mload(add(res, 0x20))
			baseTrackingAccrued := mload(add(res, 0x40))
			assetsIn := mload(add(res, 0x60))
			reserved := mload(add(res, 0x80))
		}
	}

	function borrowBalanceOf(Currency comet, address account) internal view returns (uint256 borrowBalance) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x374c49b400000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comet, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			borrowBalance := mload(0x00)
		}
	}

	function collateralBalanceOf(
		Currency comet,
		Currency asset,
		address account
	) internal view returns (uint256 collateralBalance) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x5c2549ee00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comet, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			collateralBalance := mload(0x00)
		}
	}

	function getAssetInfoByAddress(
		Currency comet,
		Currency asset
	)
		internal
		view
		returns (
			uint8 offset,
			address priceFeed,
			uint16 scale,
			uint16 borrowCollateralFactor,
			uint16 liquidateCollateralFactor,
			uint16 liquidationFactor,
			uint128 supplyCap
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x3b3bec2e00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comet, ptr, 0x24, res, 0x100)) {
				returndatacopy(0x00, 0x00, returndatasize())
				revert(0x00, returndatasize())
			}

			offset := mload(res)
			priceFeed := mload(add(res, 0x40))
			scale := mload(add(res, 0x60))
			borrowCollateralFactor := div(mload(add(res, 0x80)), DESCALE)
			liquidateCollateralFactor := div(mload(add(res, 0xa0)), DESCALE)
			liquidationFactor := div(mload(add(res, 0xc0)), DESCALE)
			supplyCap := mload(add(res, 0xe0))
		}
	}

	function getAssetConfig(
		address configurator,
		Currency comet,
		Currency asset
	) internal view returns (AssetConfig memory assetConfig) {
		AssetConfig[] memory configs = getConfiguration(configurator, comet).assetConfigs;

		uint256 length = configs.length;
		uint8 i;

		unchecked {
			while (i < length) {
				if (asset == configs[i].asset) return configs[i];
				i = i + 1;
			}
		}
	}

	function getConfiguration(
		address configurator,
		Currency comet
	) internal view returns (Configuration memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xc44b11f700000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(comet, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), configurator, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Configuration));
	}

	function getAssetInfo(
		Currency comet,
		uint8 offset
	)
		internal
		view
		returns (
			Currency asset,
			address priceFeed,
			uint64 scale,
			uint64 borrowCollateralFactor,
			uint64 liquidateCollateralFactor,
			uint64 liquidationFactor,
			uint128 supplyCap
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0xc8c7fe6b00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), offset)

			if iszero(staticcall(gas(), comet, ptr, 0x24, res, 0x100)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			asset := mload(add(res, 0x20))
			priceFeed := mload(add(res, 0x40))
			scale := mload(add(res, 0x60))
			borrowCollateralFactor := mload(add(res, 0x80))
			liquidateCollateralFactor := mload(add(res, 0xa0))
			liquidationFactor := mload(add(res, 0xc0))
			supplyCap := mload(add(res, 0xe0))
		}
	}

	function numAssets(Currency comet) internal view returns (uint8 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa46fe83b00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comet, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function getAssetPrice(Currency comet, Currency asset) internal view returns (uint256) {
		if (asset == WETH) return WadRayMath.WAD;

		uint256 ethPrice = getETHPrice();
		uint256 price = getPrice(comet, getPriceFeed(comet, asset));

		return derivePrice(price, ethPrice, 8, 8, 18);
	}

	function getPrice(Currency comet, address feed) internal view returns (uint256 price) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x41976e0900000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(feed, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comet, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			price := mload(0x00)
		}
	}

	function getPriceFeed(Currency comet, Currency asset) internal view returns (address) {
		return
			!isBaseAsset(comet, asset)
				? getAssetConfig(CONFIGURATOR, comet, asset).priceFeed
				: baseTokenPriceFeed(comet);
	}

	function getSupplyRate(
		Currency comet,
		uint256 utilization
	) internal view virtual returns (uint64 supplyRate) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd955759d00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), utilization)

			if iszero(staticcall(gas(), comet, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			supplyRate := mul(mul(mload(0x00), SECONDS_PER_YEAR), 0x64)
		}
	}

	function getBorrowRate(
		Currency comet,
		uint256 utilization
	) internal view virtual returns (uint64 borrowRate) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x9fa83b5a00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), utilization)

			if iszero(staticcall(gas(), comet, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			borrowRate := mul(mul(mload(0x00), SECONDS_PER_YEAR), 0x64)
		}
	}

	function rewardConfig(
		address rewards,
		Currency comet
	) internal view returns (Currency rewardAsset, uint64 rescaleFactor, bool shouldUpscale) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x2289b6b800000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(comet, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), rewards, ptr, 0x24, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			rewardAsset := mload(res)
			rescaleFactor := mload(add(res, 0x20))
			shouldUpscale := mload(add(res, 0x40))
		}
	}

	function isBaseAsset(Currency comet, Currency asset) internal view returns (bool) {
		return baseToken(comet) == asset;
	}

	function baseToken(Currency comet) internal view returns (Currency baseAsset) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xc55dae6300000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comet, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			baseAsset := mload(0x00)
		}
	}

	function baseTokenPriceFeed(Currency comet) internal view returns (address baseFeed) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xe7dad6bd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comet, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			baseFeed := mload(0x00)
		}
	}

	function _verifyReserve(
		Currency comet,
		Currency asset,
		uint256 amount,
		bool useAsCollateral
	) internal view virtual override returns (ReserveError) {
		if (comet.isZero() || asset.isZero()) return ReserveError.ZeroAddress;
		if (amount == 0) return ReserveError.ZeroAmount;

		if (useAsCollateral) {
			//
		}

		// (, , , , , , , uint8 pauseFlags) = totalsBasic(comet);

		return ReserveError.NoError;
	}

	function computeUtilization(
		uint64 baseSupplyIndex,
		uint64 baseBorrowIndex,
		uint104 totalSupplyBase,
		uint104 totalBorrowBase
	) internal pure returns (uint256 utilization) {
		uint256 totalSupply = FullMath.mulDiv(totalSupplyBase, baseSupplyIndex, BASE_INDEX_SCALE);
		uint256 totalBorrow = FullMath.mulDiv(totalBorrowBase, baseBorrowIndex, BASE_INDEX_SCALE);

		if (totalSupply != 0) {
			utilization = FullMath.mulDiv(totalBorrow, FACTOR_SCALE, totalSupply);
		}
	}

	function presentValue(
		int104 principal,
		uint64 supplyIndex,
		uint64 borrowIndex
	) internal pure returns (int104) {
		if (principal < 0) return -int104((uint104(principal) * borrowIndex) / BASE_INDEX_SCALE);
		else return int104((uint104(principal) * supplyIndex) / BASE_INDEX_SCALE);
	}

	function principalValue(
		int104 present,
		uint64 supplyIndex,
		uint64 borrowIndex
	) internal pure returns (int104) {
		if (present < 0)
			return -int104((uint104(present) * BASE_INDEX_SCALE + borrowIndex - 1) / borrowIndex);
		else return int104((uint104(present) * BASE_INDEX_SCALE) / supplyIndex);
	}

	function getFlag(uint16 flags, uint8 offset) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(flags, shl(0x01, offset))
		}
	}
}
