// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICTokenRegistry} from "src/interfaces/ICTokenRegistry.sol";
import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Authority} from "src/base/Authority.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

/// @title CTokenRegistry
/// @notice Registry of cTokens

contract CTokenRegistry is ICTokenRegistry, Authority, Initializable {
	using Arrays for Currency[];

	mapping(address cToken => address underlying) internal _cTokenToUnderlying;
	mapping(address underlying => address cToken) internal _underlyingToCToken;

	bytes32 public immutable protocol;
	address public immutable COMPTROLLER;
	Currency public immutable cNATIVE;
	Currency public immutable cETH;
	Currency public immutable WRAPPED_NATIVE;
	Currency public immutable WETH;

	IAddressResolver internal resolver;

	constructor(
		bytes32 _protocol,
		address _comptroller,
		Currency _cNative,
		Currency _cETH,
		Currency _wrappedNative,
		Currency _weth
	) {
		protocol = _protocol;
		COMPTROLLER = _comptroller;
		cNATIVE = _cNative;
		cETH = _cETH;
		WRAPPED_NATIVE = _wrappedNative;
		WETH = _weth;
	}

	function initialize(address _resolver) external initializer {
		resolver = IAddressResolver(_resolver);

		if (!cNATIVE.isZero()) {
			register(cNATIVE.toAddress(), WRAPPED_NATIVE.toAddress());
		}

		if (!cETH.isZero() && cETH != cNATIVE) {
			register(cETH.toAddress(), WETH.toAddress());
		}
	}

	function registerCTokens(Currency[] calldata cTokens) external authorized {
		uint256 length = cTokens.length;
		uint256 i;

		while (i < length) {
			register(cTokens.at(i).toAddress(), toUnderlying(cTokens.at(i)));

			unchecked {
				i = i + 1;
			}
		}
	}

	function registerCToken(Currency cToken) external authorized {
		register(cToken.toAddress(), toUnderlying(cToken));
	}

	function deregisterCTokens(Currency[] calldata cTokens) external authorized {
		uint256 length = cTokens.length;
		uint256 i;

		while (i < length) {
			deregister(cTokens.at(i).toAddress());

			unchecked {
				i = i + 1;
			}
		}
	}

	function deregisterCToken(Currency cToken) external authorized {
		deregister(cToken.toAddress());
	}

	function register(address cToken, address underlying) internal {
		_cTokenToUnderlying[cToken] = underlying;
		_underlyingToCToken[underlying] = cToken;

		emit CTokenRegistered(cToken, underlying);
	}

	function deregister(address cToken) internal {
		address underlying = _cTokenToUnderlying[cToken];
		if (underlying == address(0)) revert Errors.NotExists();

		delete _cTokenToUnderlying[cToken];
		delete _underlyingToCToken[underlying];

		emit CTokenDeregistered(cToken, underlying);
	}

	function getAllCTokens() public view returns (Currency[] memory) {
		address comptroller = COMPTROLLER;

		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb0772d0b00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comptroller, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())

			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[]));
	}

	function getCTokens() external view returns (Currency[] memory cTokens) {
		Currency[] memory allCTokens = getAllCTokens();

		uint256 length = allCTokens.length;
		uint256 i;
		uint256 count;

		cTokens = new Currency[](length);

		while (i < length) {
			if (!isDeprecated(allCTokens.at(i))) {
				cTokens[count] = allCTokens.at(i);

				unchecked {
					count = count + 1;
				}
			}

			unchecked {
				i = i + 1;
			}
		}

		assembly ("memory-safe") {
			mstore(cTokens, count)
		}
	}

	function cTokenToUnderlying(Currency cToken) external view returns (Currency underlying) {
		if ((underlying = Currency.wrap(_cTokenToUnderlying[cToken.toAddress()])).isZero()) {
			revert Errors.NotExists();
		}
	}

	function underlyingToCToken(Currency underlying) external view returns (Currency cToken) {
		if ((cToken = Currency.wrap(_underlyingToCToken[underlying.toAddress()])).isZero()) {
			revert Errors.NotExists();
		}
	}

	function getCompAddress() external view returns (Currency comp) {
		address comptroller = COMPTROLLER;

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

	function getPriceOracle() external view returns (address oracle) {
		address comptroller = COMPTROLLER;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x7dc0d1d000000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), comptroller, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			oracle := mload(0x00)
		}
	}

	function isDeprecated(Currency cToken) public view virtual returns (bool deprecated) {
		address comptroller = COMPTROLLER;

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

	function toUnderlying(Currency cToken) internal view returns (address underlying) {
		if (cToken == cNATIVE) return WRAPPED_NATIVE.toAddress();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6f307dc300000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			underlying := mload(0x00)
		}
	}

	function isAuthorized(address account) internal view virtual override returns (bool) {
		return resolver.getACLManager().isReserveListingAdmin(account);
	}
}
