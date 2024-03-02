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

/// @title AaveV2Adapter
/// @notice Provides the functionality of making calls to Aave-V2 contracts for the Client

contract AaveV2Adapter is ILender, BaseLender {
	using BytesLib for bytes;
	using CurrencyLibrary for Currency;
	using FullMath for uint256;
	using PercentageMath for uint256;
	using WadRayMath for uint256;

	uint256 internal constant BORROW_MASK					=	0x5555555555555555555555555555555555555555555555555555555555555555; // prettier-ignore

	uint256 internal constant LTV_MASK 						=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
	uint256 internal constant LIQUIDATION_THRESHOLD_MASK	=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
	uint256 internal constant DECIMALS_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant ACTIVE_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant FROZEN_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant BORROWING_MASK				=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore

	uint256 internal constant LIQUIDATION_THRESHOLD_OFFSET = 16;

	uint256 internal constant SECONDS_PER_DAY = 86400;
	uint256 internal constant SECONDS_PER_YEAR = 31536000;

	address internal immutable LENDING_POOL;
	address internal immutable INCENTIVES;
	address internal immutable PRICE_ORACLE;

	constructor(
		address _resolver,
		bytes32 _protocol,
		address _lendingPool,
		address _incentives,
		address _priceOracle,
		address _denomination,
		address _ethUsdFeed,
		Currency _wrappedNative,
		Currency _weth
	) BaseLender(_resolver, _protocol, _denomination, _ethUsdFeed, _wrappedNative, _weth) {
		LENDING_POOL = _lendingPool;
		INCENTIVES = _incentives;
		PRICE_ORACLE = _priceOracle;
	}

	function supply(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 liquidityIndex, uint40 lastUpdateTimestamp)
	{
		address lendingPool = LENDING_POOL;

		(, Currency asset, uint256 amount) = decode(params);

		verifyReserve(CurrencyLibrary.ZERO, asset, amount, true);

		approveIfNeeded(asset, lendingPool, amount);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xe8eda9df00000000000000000000000000000000000000000000000000000000) // deposit(address,uint256,address,uint16)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)
			mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x64), 0x00)

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0x84, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		(, liquidityIndex, , , , , lastUpdateTimestamp, , , , , ) = getReserveData(lendingPool, asset);
	}

	function borrow(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 variableBorrowIndex, uint40 lastUpdateTimestamp)
	{
		address lendingPool = LENDING_POOL;

		(, Currency asset, uint256 amount) = decode(params);

		verifyReserve(CurrencyLibrary.ZERO, asset, amount, false);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa415bcad00000000000000000000000000000000000000000000000000000000) // borrow(address,uint256,uint256,uint16,address)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)
			mstore(add(ptr, 0x44), 0x02)
			mstore(add(ptr, 0x64), 0x00)
			mstore(add(ptr, 0x84), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0xa4, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		(, , variableBorrowIndex, , , , lastUpdateTimestamp, , , , , ) = getReserveData(lendingPool, asset);
	}

	function repay(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 variableBorrowIndex, uint40 lastUpdateTimestamp)
	{
		address lendingPool = LENDING_POOL;

		(, Currency asset, uint256 amount) = decode(params);

		// verifyReserve(CurrencyLibrary.ZERO, asset, amount, false);

		approveIfNeeded(asset, lendingPool, amount);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x573ade8100000000000000000000000000000000000000000000000000000000) // repay(address,uint256,uint256,address)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)
			mstore(add(ptr, 0x44), 0x02)
			mstore(add(ptr, 0x64), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0x84, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		(, , variableBorrowIndex, , , , lastUpdateTimestamp, , , , , ) = getReserveData(lendingPool, asset);
	}

	function redeem(
		bytes calldata params
	)
		public
		payable
		authorized
		checkDelegateCall
		returns (uint128 liquidityIndex, uint40 lastUpdateTimestamp)
	{
		address lendingPool = LENDING_POOL;

		(, Currency asset, uint256 amount) = decode(params);

		// verifyReserve(CurrencyLibrary.ZERO, asset, amount, true);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x69328dec00000000000000000000000000000000000000000000000000000000) // withdraw(address,uint256,address)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)
			mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0x64, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		(, liquidityIndex, , , , , lastUpdateTimestamp, , , , , ) = getReserveData(lendingPool, asset);
	}

	function enterMarket(bytes calldata params) public payable authorized checkDelegateCall {
		setAsCollateral(LENDING_POOL, Currency.wrap(params.toAddress()), true);
	}

	function exitMarket(bytes calldata params) public payable authorized checkDelegateCall {
		setAsCollateral(LENDING_POOL, Currency.wrap(params.toAddress()), false);
	}

	function setAsCollateral(address lendingPool, Currency asset, bool useAsCollateral) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x5a3b74b900000000000000000000000000000000000000000000000000000000) // setUserUseReserveAsCollateral(address,bool)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(useAsCollateral, 0xff))

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function claimRewards(bytes calldata) public payable authorized checkDelegateCall {
		address incentives = INCENTIVES;

		bytes memory markets = abi.encode(getMarketsIn(LENDING_POOL, address(this)));

		if (getPendingRewards(incentives, markets, address(this)) != 0) {
			assembly ("memory-safe") {
				let ptr := mload(0x40)

				mstore(ptr, 0x4148530400000000000000000000000000000000000000000000000000000000) // claimRewardsToSelf(address[],uint256)
				mstore(add(ptr, 0x04), 0x40) // index where markets array starts at
				mstore(add(ptr, 0x24), sub(exp(0x02, 0x100), 0x01)) // type(uint256).max
				mstore(add(ptr, 0x44), div(sub(mload(markets), 0x40), 0x20)) // length of markets

				let offset := add(ptr, 0x64)
				let guard := add(offset, mload(markets))

				for {
					let i := add(markets, 0x20)
				} lt(offset, guard) {
					offset := add(offset, 0x20)
					i := add(i, 0x20)
				} {
					mstore(offset, mload(i)) // stores the address of market at current index
				}

				mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

				if iszero(call(gas(), incentives, 0x00, ptr, add(mload(markets), 0x64), 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
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
		(totalCollateral, totalLiability, availableLiquidity, , , healthFactor) = getUserAccountData(
			LENDING_POOL,
			params.toAddress()
		);

		if (denomination == USD) {
			uint256 ethPrice = getETHPrice();

			totalCollateral = derivePrice(totalCollateral, ethPrice, 8, 8, 18);
			totalLiability = derivePrice(totalLiability, ethPrice, 8, 8, 18);
			availableLiquidity = derivePrice(availableLiquidity, ethPrice, 8, 8, 18);
		}
	}

	function getSupplyBalance(bytes calldata params) external view returns (uint256) {
		Currency asset;
		address account;

		assembly ("memory-safe") {
			asset := calldataload(params.offset)
			account := calldataload(add(params.offset, 0x20))
		}

		(, , , , , , , Currency aToken, , , , ) = getReserveData(LENDING_POOL, asset);

		return aToken.balanceOf(account);
	}

	function getBorrowBalance(bytes calldata params) external view returns (uint256) {
		Currency asset;
		address account;

		assembly ("memory-safe") {
			asset := calldataload(params.offset)
			account := calldataload(add(params.offset, 0x20))
		}

		(, , , , , , , , , Currency vdToken, , ) = getReserveData(LENDING_POOL, asset);

		return vdToken.balanceOf(account);
	}

	function getPendingRewards(bytes calldata params) external view returns (uint256) {
		return
			getPendingRewards(
				INCENTIVES,
				abi.encode(getMarketsIn(LENDING_POOL, params.toAddress())),
				params.toAddress()
			);
	}

	function getReserveData(bytes calldata params) external view returns (ReserveData memory reserveData) {
		Currency asset;

		assembly ("memory-safe") {
			asset := calldataload(params.offset)
		}

		uint256 configuration;
		uint256 currentLiquidityRate;
		uint256 currentVariableBorrowRate;

		(
			configuration,
			reserveData.supplyIndex,
			reserveData.borrowIndex,
			currentLiquidityRate,
			currentVariableBorrowRate,
			,
			reserveData.lastAccrualTime,
			reserveData.collateralMarket,
			,
			reserveData.borrowMarket,
			,

		) = getReserveData(LENDING_POOL, asset);

		reserveData.supplyRate = currentLiquidityRate.rayToWad();
		reserveData.borrowRate = currentVariableBorrowRate.rayToWad();

		reserveData.priceFeed = getPriceFeed(PRICE_ORACLE, asset);
		reserveData.price = getAssetPrice(asset);

		reserveData.ltv = getValue(configuration, LTV_MASK, 0);

		bool isActive = isReserveActive(configuration);
		reserveData.isCollateral = isCollateralAsset(configuration);
		reserveData.canSupply = isCollateralAsset(configuration) && isActive;
		reserveData.canBorrow = isBorrowAsset(configuration) && isActive;
	}

	function getReserveIndices(
		bytes calldata params
	) external view returns (uint256 supplyIndex, uint256 borrowIndex, uint256 lastAccrualTime) {
		(, supplyIndex, borrowIndex, , , , lastAccrualTime, , , , , ) = getReserveData(
			LENDING_POOL,
			Currency.wrap(params.toAddress())
		);
	}

	function getLtv(bytes calldata params) external view returns (uint256) {
		return getValue(getConfiguration(LENDING_POOL, Currency.wrap(params.toAddress())), LTV_MASK, 0);
	}

	function getAssetPrice(bytes calldata params) external view returns (uint256) {
		return getAssetPrice(Currency.wrap(params.toAddress()));
	}

	function getPendingRewards(
		address incentives,
		bytes memory markets,
		address account
	) internal view returns (uint256 rewards) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x198fa81e00000000000000000000000000000000000000000000000000000000) // getRewardsBalance(address[],address)
			mstore(add(ptr, 0x04), 0x40) // index where markets array starts at
			mstore(add(ptr, 0x24), and(account, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), div(sub(mload(markets), 0x40), 0x20)) // length of markets

			let offset := add(ptr, 0x64)
			let guard := add(offset, mload(markets))

			for {
				let i := add(markets, 0x20)
			} lt(offset, guard) {
				offset := add(offset, 0x20)
				i := add(i, 0x20)
			} {
				mstore(offset, mload(i)) // stores the address of market at current index
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			if iszero(staticcall(gas(), incentives, ptr, add(mload(markets), 0x64), 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			rewards := mload(0x00)
		}
	}

	function getMarketsIn(
		address lendingPool,
		address account
	) internal view returns (Currency[] memory markets) {
		uint256 userConfig = getUserConfiguration(lendingPool, account);

		if (userConfig != 0) {
			Currency[] memory reserves = getReservesList(lendingPool);

			uint256 length = reserves.length;
			uint256 count;
			uint256 i;

			unchecked {
				markets = new Currency[](length * 2);

				while (i < length) {
					if (isAssetIn(userConfig, i)) {
						(, , , , , , , Currency aToken, , Currency vdToken, , ) = getReserveData(
							lendingPool,
							reserves[i]
						);

						if (isSupplying(userConfig, i)) {
							markets[count] = aToken;
							count = count + 1;
						}

						if (isBorrowing(userConfig, i)) {
							markets[count] = vdToken;
							count = count + 1;
						}
					}

					i = i + 1;
				}
			}

			assembly ("memory-safe") {
				mstore(markets, count)
			}
		}
	}

	function getReservesList(address lendingPool) internal view returns (Currency[] memory assets) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd1946dbc00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), lendingPool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[]));
	}

	function getRewardAsset(address incentives) internal view returns (Currency rewardAsset) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x99248ea700000000000000000000000000000000000000000000000000000000) // REWARD_TOKEN()

			if iszero(staticcall(gas(), incentives, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			rewardAsset := mload(0x00)
		}
	}

	function getReserveData(
		address lendingPool,
		Currency asset
	)
		internal
		view
		returns (
			uint256 configuration,
			uint128 liquidityIndex,
			uint128 variableBorrowIndex,
			uint128 currentLiquidityRate,
			uint128 currentVariableBorrowRate,
			uint128 currentStableBorrowRate,
			uint40 lastUpdateTimestamp,
			Currency aToken,
			Currency stableDebtToken,
			Currency variableDebtToken,
			address interestRateStrategy,
			uint8 id
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x35ea6a7500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x24, res, 0x180)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			configuration := mload(res)
			liquidityIndex := mload(add(res, 0x20))
			variableBorrowIndex := mload(add(res, 0x40))
			currentLiquidityRate := mload(add(res, 0x60))
			currentVariableBorrowRate := mload(add(res, 0x80))
			currentStableBorrowRate := mload(add(res, 0xa0))
			lastUpdateTimestamp := mload(add(res, 0xc0))
			aToken := mload(add(res, 0xe0))
			stableDebtToken := mload(add(res, 0x100))
			variableDebtToken := mload(add(res, 0x120))
			interestRateStrategy := mload(add(res, 0x140))
			id := mload(add(res, 0x160))
		}
	}

	function getUserAccountData(
		address lendingPool,
		address account
	)
		internal
		view
		returns (
			uint256 totalCollateral,
			uint256 totalDebt,
			uint256 availableBorrows,
			uint256 currentLiquidationThreshold,
			uint256 ltv,
			uint256 healthFactor
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0xbf92857c00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x24, res, 0xc0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			totalCollateral := mload(res)
			totalDebt := mload(add(res, 0x20))
			availableBorrows := mload(add(res, 0x40))
			currentLiquidationThreshold := mload(add(res, 0x60))
			ltv := mload(add(res, 0x80))
			healthFactor := mload(add(res, 0xa0))
		}
	}

	function getConfiguration(
		address lendingPool,
		Currency asset
	) internal view returns (uint256 configuration) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xc44b11f700000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			configuration := mload(0x00)
		}
	}

	function getUserConfiguration(
		address lendingPool,
		address account
	) internal view returns (uint256 configuration) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4417a58300000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			configuration := mload(0x00)
		}
	}

	function getAssetPrice(Currency asset) internal view returns (uint256) {
		if (asset == WETH) return WadRayMath.WAD;

		return
			denomination != ETH
				? derivePrice(getAssetPrice(PRICE_ORACLE, asset), getETHPrice(), 8, 8, 18)
				: getAssetPrice(PRICE_ORACLE, asset);
	}

	function getAssetPrice(address oracle, Currency asset) internal view returns (uint256 price) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb3596f0700000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), oracle, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			price := mload(0x00)
		}
	}

	function getPriceFeed(address oracle, Currency asset) internal view returns (address priceFeed) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x92bf2be000000000000000000000000000000000000000000000000000000000) // getSourceOfAsset(address)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), oracle, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			priceFeed := mload(0x00)

			if iszero(priceFeed) {
				mstore(ptr, 0x6210308c00000000000000000000000000000000000000000000000000000000) // getFallbackOracle()

				if iszero(staticcall(gas(), oracle, ptr, 0x04, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				priceFeed := mload(0x00)
			}
		}
	}

	function _verifyReserve(
		Currency,
		Currency asset,
		uint256 amount,
		bool useAsCollateral
	) internal view virtual override returns (ReserveError) {
		if (asset.isZero()) return ReserveError.ZeroAddress;
		if (amount == 0) return ReserveError.ZeroAmount;

		(uint256 configuration, , , , , , , Currency aToken, , Currency vdToken, , ) = getReserveData(
			LENDING_POOL,
			asset
		);

		if (!isReserveActive(configuration)) return ReserveError.NotActive;

		if (useAsCollateral) {
			if (aToken.isZero()) return ReserveError.NotSupported;
			if (!isCollateralAsset(configuration)) return ReserveError.NotCollateral;
		} else {
			if (vdToken.isZero()) return ReserveError.NotSupported;
			if (!isBorrowAsset(configuration)) return ReserveError.NotBorrowable;
		}

		return ReserveError.NoError;
	}

	function isCollateralAsset(uint256 configuration) internal pure returns (bool) {
		return
			getValue(configuration, LTV_MASK, 0) != 0 &&
			getValue(configuration, LIQUIDATION_THRESHOLD_MASK, LIQUIDATION_THRESHOLD_OFFSET) != 0;
	}

	function isBorrowAsset(uint256 configuration) internal pure returns (bool) {
		return getFlag(configuration, BORROWING_MASK);
	}

	function isReserveActive(uint256 configuration) internal pure returns (bool) {
		return getFlag(configuration, ACTIVE_MASK) && !getFlag(configuration, FROZEN_MASK);
	}

	function getValue(
		uint256 configuration,
		uint256 mask,
		uint256 offset
	) internal pure returns (uint256 value) {
		assembly ("memory-safe") {
			value := shr(offset, and(configuration, not(mask)))
		}
	}

	function getFlag(uint256 configuration, uint256 mask) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(configuration, not(mask))
		}
	}

	function isAssetIn(uint256 configuration, uint256 reserveId) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(shr(mul(reserveId, 0x02), configuration), 0x03)
		}
	}

	function isBorrowing(uint256 configuration, uint256 reserveId) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(shr(mul(reserveId, 0x02), configuration), 0x01)
		}
	}

	function isSupplying(uint256 configuration, uint256 reserveId) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(shr(add(mul(reserveId, 0x02), 0x01), configuration), 0x01)
		}
	}

	function getNormalizedIncome(
		uint256 supplyRate,
		uint256 supplyIndex,
		uint40 timeElapsed
	) internal pure returns (uint256) {
		unchecked {
			if (timeElapsed == 0) return supplyIndex;

			uint256 linearInterest = WadRayMath.RAY + supplyRate.mulDiv(timeElapsed, SECONDS_PER_YEAR);

			return linearInterest.rayMul(supplyIndex);
		}
	}

	function getNormalizedDebt(
		uint256 borrowRate,
		uint256 borrowIndex,
		uint40 timeElapsed
	) internal pure returns (uint256) {
		if (timeElapsed == 0) return borrowIndex;

		uint256 expMinusOne;
		uint256 expMinusTwo;
		uint256 basePowerTwo;
		uint256 basePowerThree;

		unchecked {
			expMinusOne = timeElapsed - 1;
			expMinusTwo = timeElapsed > 2 ? timeElapsed - 2 : 0;

			basePowerTwo = borrowRate.rayMul(borrowRate) / (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
			basePowerThree = basePowerTwo.rayMul(borrowRate) / SECONDS_PER_YEAR;
		}

		uint256 secondTerm = timeElapsed * expMinusOne * basePowerTwo;
		uint256 thirdTerm = timeElapsed * expMinusOne * expMinusTwo * basePowerThree;

		unchecked {
			uint256 compoundedInterest = WadRayMath.RAY +
				borrowRate.mulDiv(timeElapsed, SECONDS_PER_YEAR) +
				(secondTerm / 2) +
				(thirdTerm / 6);

			return compoundedInterest.rayMul(borrowIndex);
		}
	}

	// function decode(bytes calldata params) internal pure returns (Currency asset, uint256 amount) {
	// 	assembly ("memory-safe") {
	// 		asset := calldataload(params.offset)
	// 		amount := calldataload(add(params.offset, 0x20))
	// 	}
	// }
}
