// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {ILender} from "src/interfaces/ILender.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary, toCurrency} from "src/types/Currency.sol";
import {CurrencyState} from "test/shared/states/CurrencyState.sol";
import {AaveConfig, AaveMarket} from "test/shared/states/DataTypes.sol";
import {Utils} from "./Utils.sol";

abstract contract AaveUtils is CommonBase, CurrencyState, Utils {
	uint256 constant BORROW_MASK					=	0x5555555555555555555555555555555555555555555555555555555555555555; // prettier-ignore
	uint256 constant COLLATERAL_MASK				=	0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; // prettier-ignore

	uint256 constant LTV_MASK						=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
	uint256 constant LIQUIDATION_THRESHOLD_MASK		=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
	uint256 constant ACTIVE_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
	uint256 constant FROZEN_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
	uint256 constant BORROWING_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore
	uint256 constant PAUSED_MASK					=	0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF; // prettier-ignore
	uint256 constant DEBT_CEILING_MASK				=	0xF0000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

	uint256 constant LIQUIDATION_THRESHOLD_OFFSET = 16;
	uint256 constant DEBT_CEILING_OFFSET = 212;

	AaveConfig aaveV3Config;
	AaveConfig aaveV2Config;

	function setUpAave(uint256 chainId) internal virtual {
		if (chainId == ETHEREUM_CHAIN_ID) {
			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
				lendingPool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
				incentives: 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb,
				oracle: 0x54586bE62E3c3580375aE3723C145253060Ca0C2,
				denomination: USD
			});

			aaveV2Config = AaveConfig({
				protocol: AAVE_V2_ID,
				provider: 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5,
				lendingPool: 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9,
				incentives: 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5,
				oracle: 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9,
				denomination: ETH
			});
		} else if (chainId == OPTIMISM_CHAIN_ID) {
			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
				lendingPool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
				incentives: 0x929EC64c34a17401F460460D4B9390518E5B473e,
				oracle: 0xD81eb3728a631871a7eBBaD631b5f424909f0c77,
				denomination: USD
			});
		} else if (chainId == POLYGON_CHAIN_ID) {
			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
				lendingPool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
				incentives: 0x929EC64c34a17401F460460D4B9390518E5B473e,
				oracle: 0xb023e699F5a33916Ea823A16485e259257cA8Bd1,
				denomination: USD
			});

			aaveV2Config = AaveConfig({
				protocol: AAVE_V2_ID,
				provider: 0xd05e3E715d945B59290df0ae8eF85c1BdB684744,
				lendingPool: 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf,
				incentives: 0x357D51124f59836DeD84c8a1730D72B749d8BC23,
				oracle: 0x0229F777B0fAb107F9591a41d5F02E4e98dB6f2d,
				denomination: ETH
			});
		} else if (chainId == ARBITRUM_CHAIN_ID) {
			aaveV3Config = AaveConfig({
				protocol: AAVE_V3_ID,
				provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
				lendingPool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
				incentives: 0x929EC64c34a17401F460460D4B9390518E5B473e,
				oracle: 0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7,
				denomination: USD
			});
		}

		if (aaveV3Config.protocol != bytes32(0)) {
			vm.label(aaveV3Config.lendingPool, "LendingPoolV3");
			vm.label(aaveV3Config.incentives, "RewardsController");
			vm.label(aaveV3Config.oracle, "AaveV3Oracle");
		}

		if (aaveV2Config.protocol != bytes32(0)) {
			vm.label(aaveV2Config.lendingPool, "LendingPoolV2");
			vm.label(aaveV2Config.incentives, "IncentivesController");
			vm.label(aaveV2Config.oracle, "AaveV2Oracle");
		}
	}

	function getAddress(address provider, bytes32 key) internal view returns (address value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x21f8a72100000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), key)

			if iszero(staticcall(gas(), provider, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function getAaveMarkets(
		Currency[] memory assets,
		bool isV3
	) internal returns (AaveMarket[] memory aaveMarkets) {
		aaveMarkets = new AaveMarket[](assets.length);

		for (uint256 i; i < assets.length; ++i) aaveMarkets[i] = getAaveMarket(assets[i], isV3);
	}

	function getAaveMarket(Currency asset, bool isV3) internal returns (AaveMarket memory) {
		uint256 configuration;
		Currency aToken;
		Currency vdToken;
		uint16 id;

		if (!isV3) {
			(configuration, , , , , , , aToken, , vdToken, , id) = getV2ReserveData(asset);
		} else {
			(configuration, , , , , , , id, aToken, , vdToken, , , , ) = getV3ReserveData(asset);
		}

		vm.label(asset.toAddress(), symbol(asset));
		vm.label(aToken.toAddress(), symbol(aToken));
		vm.label(vdToken.toAddress(), symbol(vdToken));

		return AaveMarket(aToken, vdToken, asset, uint16(getValue(configuration, LTV_MASK, 0)), id);
	}

	function getReservesList(bool isV3) internal view returns (Currency[] memory) {
		address lendingPool = !isV3 ? aaveV2Config.lendingPool : aaveV3Config.lendingPool;

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

	function getV3ReserveData(
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
		address lendingPool = aaveV3Config.lendingPool;

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

	function getV2ReserveData(
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
		address lendingPool = aaveV2Config.lendingPool;

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
		address account,
		bool isV3
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
		address lendingPool = !isV3 ? aaveV2Config.lendingPool : aaveV3Config.lendingPool;

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

	function getConfiguration(Currency asset, bool isV3) internal view returns (uint256 configuration) {
		address lendingPool = !isV3 ? aaveV2Config.lendingPool : aaveV3Config.lendingPool;

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

	function getUserConfiguration(address account, bool isV3) internal view returns (uint256 configuration) {
		address lendingPool = !isV3 ? aaveV2Config.lendingPool : aaveV3Config.lendingPool;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4417a58300000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			configuration := mload(0x00)
		}
	}

	function getAavePrice(Currency asset, bool isV3) internal view returns (uint256 price) {
		(address oracle, address denomination) = !isV3
			? (aaveV2Config.oracle, aaveV2Config.denomination)
			: (aaveV3Config.oracle, aaveV3Config.denomination);

		price = _getAavePrice(oracle, asset);

		if (denomination == USD) {
			uint256 ethPrice = _getAavePrice(oracle, WETH);
			price = derivePrice(price, ethPrice, 8, 8, 18);
		}
	}

	function _getAavePrice(address oracle, Currency asset) private view returns (uint256 price) {
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

	function getRewardsList(bool isV3) internal view returns (Currency[] memory rewardAssets) {
		address incentives = !isV3 ? aaveV2Config.incentives : aaveV3Config.incentives;

		if (!isV3) {
			if (aaveV2Config.protocol == AAVE_V2_ID) {
				rewardAssets = new Currency[](1);
				rewardAssets[0] = getRewardAsset(incentives);
			}
		} else {
			bytes memory returndata;

			assembly ("memory-safe") {
				let ptr := mload(0x40)

				mstore(ptr, 0xb45ac1a900000000000000000000000000000000000000000000000000000000)

				if iszero(staticcall(gas(), incentives, ptr, 0x04, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
				mstore(returndata, returndatasize())
				returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
			}

			rewardAssets = abi.decode(returndata, (Currency[]));
		}
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

	function getRewardsByAsset(Currency market) internal view returns (Currency[] memory) {
		address incentives = aaveV3Config.incentives;

		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6657732f00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(market, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), incentives, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[]));
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
}
