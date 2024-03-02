// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILender} from "src/interfaces/ILender.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseLender} from "./BaseLender.sol";

/// @title AaveV3Adapter
/// @notice Provides the functionality of making calls to Aave-V3 contracts for the Client

contract AaveV3Adapter is ILender, BaseLender {
	using Arrays for Currency[];
	using BytesLib for bytes;
	using CurrencyLibrary for Currency;
	using FullMath for uint256;
	using PercentageMath for uint256;
	using WadRayMath for uint256;

	uint256 internal constant BORROW_MASK					=	0x5555555555555555555555555555555555555555555555555555555555555555; // prettier-ignore
	uint256 internal constant COLLATERAL_MASK				=	0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; // prettier-ignore

	uint256 internal constant LTV_MASK						=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
	uint256 internal constant LIQUIDATION_THRESHOLD_MASK	=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
	uint256 internal constant DECIMALS_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant ACTIVE_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant FROZEN_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant BORROWING_MASK				=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant STABLE_BORROWING_MASK			=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant PAUSED_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant BORROW_CAP_MASK				=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant SUPPLY_CAP_MASK				=	0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
	uint256 internal constant DEBT_CEILING_MASK				=	0xF0000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

	uint256 internal constant LIQUIDATION_THRESHOLD_OFFSET = 16;
	uint256 internal constant DECIMALS_OFFSET = 48;
	uint256 internal constant BORROW_CAP_OFFSET = 80;
	uint256 internal constant SUPPLY_CAP_OFFSET = 116;
	uint256 internal constant DEBT_CEILING_OFFSET = 212;

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
		address _oracle,
		address _denomination,
		address _ethUsdFeed,
		Currency _wrappedNative,
		Currency _weth
	) BaseLender(_resolver, _protocol, _denomination, _ethUsdFeed, _wrappedNative, _weth) {
		LENDING_POOL = _lendingPool;
		INCENTIVES = _incentives;
		PRICE_ORACLE = _oracle;
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

		approveIfNeeded(asset, lendingPool, amount);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x617ba03700000000000000000000000000000000000000000000000000000000) // supply(address,uint256,address,uint16)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)
			mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x64), 0x00)

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0x84, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		(, liquidityIndex, , , , , lastUpdateTimestamp, , , , , , , , ) = getReserveData(lendingPool, asset);
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

		(, , , variableBorrowIndex, , , lastUpdateTimestamp, , , , , , , , ) = getReserveData(
			lendingPool,
			asset
		);
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

		approveIfNeeded(asset, lendingPool, amount);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x573ade8100000000000000000000000000000000000000000000000000000000) // repay(address,uint256,uint256,address)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)
			mstore(add(ptr, 0x44), 0x02)
			mstore(add(ptr, 0x64), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0x84, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		(, , , variableBorrowIndex, , , lastUpdateTimestamp, , , , , , , , ) = getReserveData(
			lendingPool,
			asset
		);
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

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x69328dec00000000000000000000000000000000000000000000000000000000) // withdraw(address,uint256,address)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)
			mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), lendingPool, 0x00, ptr, 0x64, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		(, liquidityIndex, , , , , lastUpdateTimestamp, , , , , , , , ) = getReserveData(lendingPool, asset);
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

		bytes memory markets = abi.encode(getMarketsIn(LENDING_POOL, incentives, true, address(this)));

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xbf90f63a00000000000000000000000000000000000000000000000000000000) // claimAllRewardsToSelf(address[])
			mstore(add(ptr, 0x04), 0x20)
			mstore(add(ptr, 0x24), div(mload(markets), 0x20))

			let offset := add(ptr, 0x44)
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

			if iszero(call(gas(), incentives, 0x00, ptr, add(mload(markets), 0x44), 0x00, 0x00)) {
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

		(, , , , , , , , Currency aToken, , , , , , ) = getReserveData(LENDING_POOL, asset);

		return aToken.balanceOf(account);
	}

	function getBorrowBalance(bytes calldata params) external view returns (uint256) {
		Currency asset;
		address account;

		assembly ("memory-safe") {
			asset := calldataload(params.offset)
			account := calldataload(add(params.offset, 0x20))
		}

		(, , , , , , , , , , Currency vdToken, , , , ) = getReserveData(LENDING_POOL, asset);

		return vdToken.balanceOf(account);
	}

	function getPendingRewards(bytes calldata params) external view returns (uint256) {
		Currency rewardAsset;
		address account;

		assembly ("memory-safe") {
			rewardAsset := calldataload(params.offset)
			account := calldataload(add(params.offset, 0x20))
		}

		return getPendingRewards(INCENTIVES, rewardAsset, account);
	}

	function getPendingRewards(
		address incentives,
		Currency rewardAsset,
		address account
	) internal view returns (uint256 accrued) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb022418c00000000000000000000000000000000000000000000000000000000) // getUserAccruedRewards(address,address)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(rewardAsset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), incentives, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			accrued := mload(0x00)
		}
	}

	function getReserveData(bytes calldata params) external view returns (ReserveData memory reserveData) {
		address lendingPool = LENDING_POOL;
		address oracle = PRICE_ORACLE;

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
			currentLiquidityRate,
			reserveData.borrowIndex,
			currentVariableBorrowRate,
			,
			reserveData.lastAccrualTime,
			,
			reserveData.collateralMarket,
			,
			reserveData.borrowMarket,
			,
			,
			,

		) = getReserveData(lendingPool, asset);

		reserveData.priceFeed = getPriceFeed(oracle, asset);
		reserveData.price = getAssetPrice(oracle, asset);

		reserveData.supplyRate = currentLiquidityRate.rayToWad();
		reserveData.borrowRate = currentVariableBorrowRate.rayToWad();
		reserveData.ltv = getValue(configuration, LTV_MASK, 0);

		bool isActive = isReserveActive(configuration);
		reserveData.isCollateral = isCollateralAsset(configuration);
		reserveData.canSupply = isCollateralAsset(configuration) && isActive;
		reserveData.canBorrow = isBorrowAsset(configuration) && isActive;
	}

	function getReserveIndices(
		bytes calldata params
	) external view returns (uint256 supplyIndex, uint256 borrowIndex, uint256 lastAccrualTime) {
		(, supplyIndex, , borrowIndex, , , lastAccrualTime, , , , , , , , ) = getReserveData(
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

	function getMarketsIn(
		address lendingPool,
		address incentives,
		bool shouldRewarded,
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
						(, , , , , , , , Currency aToken, , Currency vdToken, , , , ) = getReserveData(
							lendingPool,
							reserves.at(i)
						);

						if (
							isSupplying(userConfig, i) &&
							(!shouldRewarded || getRewardsByAsset(incentives, aToken).length != 0)
						) {
							markets[count] = aToken;
							count = count + 1;
						}

						if (
							isBorrowing(userConfig, i) &&
							(!shouldRewarded || getRewardsByAsset(incentives, vdToken).length != 0)
						) {
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

			if iszero(staticcall(gas(), lendingPool, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[]));
	}

	function getRewardsByAsset(
		address incentives,
		Currency market
	) internal view returns (Currency[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6657732f00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(market, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), incentives, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[]));
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
			uint128 currentLiquidityRate,
			uint128 variableBorrowIndex,
			uint128 currentVariableBorrowRate,
			uint128 currentStableBorrowRate,
			uint40 lastUpdateTimestamp,
			uint16 id,
			Currency aToken,
			Currency stableDebtToken,
			Currency variableDebtToken,
			address interestRateStrategy,
			uint128 accruedToTreasury,
			uint128 unbacked,
			uint128 isolationModeTotalDebt
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x35ea6a7500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x24, res, 0x1e0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			configuration := mload(res)
			liquidityIndex := mload(add(res, 0x20))
			currentLiquidityRate := mload(add(res, 0x40))
			variableBorrowIndex := mload(add(res, 0x60))
			currentVariableBorrowRate := mload(add(res, 0x80))
			currentStableBorrowRate := mload(add(res, 0xa0))
			lastUpdateTimestamp := mload(add(res, 0xc0))
			id := mload(add(res, 0xe0))
			aToken := mload(add(res, 0x100))
			stableDebtToken := mload(add(res, 0x120))
			variableDebtToken := mload(add(res, 0x140))
			interestRateStrategy := mload(add(res, 0x160))
			accruedToTreasury := mload(add(res, 0x180))
			unbacked := mload(add(res, 0x1a0))
			isolationModeTotalDebt := mload(add(res, 0x1c0))
		}
	}

	function getUserAccountData(
		address lendingPool,
		address account
	)
		internal
		view
		returns (
			uint256 totalCollateralBase,
			uint256 totalDebtBase,
			uint256 availableBorrowsBase,
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

			totalCollateralBase := mload(res)
			totalDebtBase := mload(add(res, 0x20))
			availableBorrowsBase := mload(add(res, 0x40))
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

	function isCollateralAsset(uint256 configuration) internal pure returns (bool) {
		return
			getValue(configuration, LTV_MASK, 0) != 0 &&
			getValue(configuration, LIQUIDATION_THRESHOLD_MASK, LIQUIDATION_THRESHOLD_OFFSET) != 0 &&
			!isIsolated(configuration);
	}

	function isBorrowAsset(uint256 configuration) internal pure returns (bool) {
		return getFlag(configuration, BORROWING_MASK) && !isIsolated(configuration);
	}

	function isIsolated(uint256 configuration) internal pure returns (bool) {
		return getValue(configuration, DEBT_CEILING_MASK, DEBT_CEILING_OFFSET) != 0;
	}

	function isReserveActive(uint256 configuration) internal pure returns (bool) {
		return
			getFlag(configuration, ACTIVE_MASK) &&
			!getFlag(configuration, FROZEN_MASK) &&
			!getFlag(configuration, PAUSED_MASK);
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
			flag := and(shr(shl(0x01, reserveId), configuration), 0x03)
		}
	}

	function isBorrowing(uint256 configuration, uint256 reserveId) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(shr(shl(0x01, reserveId), configuration), 0x01)
		}
	}

	function isBorrowingAny(uint256 configuration) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(configuration, BORROW_MASK)
		}
	}

	function isSupplying(uint256 configuration, uint256 reserveId) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(shr(add(0x01, shl(0x01, reserveId)), configuration), 0x01)
		}
	}

	function isSupplyingAny(uint256 configuration) internal pure returns (bool flag) {
		assembly ("memory-safe") {
			flag := and(configuration, COLLATERAL_MASK)
		}
	}

	function getNormalizedIncome(
		uint256 supplyRate,
		uint256 supplyIndex,
		uint40 timeElapsed
	) internal pure returns (uint256) {
		unchecked {
			if (timeElapsed != 0) return supplyIndex;

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
}
