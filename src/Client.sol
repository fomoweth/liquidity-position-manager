// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IClient} from "src/interfaces/IClient.sol";
import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {ClientStorage} from "src/libraries/ClientStorage.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Authority} from "src/base/Authority.sol";
import {FallbackHandler} from "src/base/FallbackHandler.sol";
import {Singleton} from "src/base/Singleton.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

/// @title Client
/// @notice

contract Client is IClient, Authority, FallbackHandler, Initializable, Singleton {
	using BytesLib for bytes;
	using CurrencyLibrary for Currency;

	mapping(bytes4 signature => address) internal _modules;
	mapping(address module => bytes4[]) internal _signatures;

	IAddressResolver internal immutable resolver;

	constructor(address _resolver) {
		resolver = IAddressResolver(_resolver);
	}

	function initialize(bytes calldata params) external initializer {
		ClientStorage.configure(params.toAddress());
	}

	function register(
		uint8 command,
		address module,
		bytes4[] calldata signatures
	) external authorized noDelegateCall {
		ClientStorage.update(ClientStorage.load(), command, module, signatures);
	}

	function deregister(address module) external authorized noDelegateCall {
		ClientStorage.clear(ClientStorage.load(), module);
	}

	function withdraw(Currency currency, uint256 amount) external authorized noDelegateCall {
		currency.transfer(_msgSender(), amount);
	}

	function owner() public view returns (address) {
		return ClientStorage.load().owner;
	}

	function isAuthorized(address account) internal view virtual override returns (bool) {
		return owner() == account;
	}

	function fallbackHandler() internal view virtual override returns (address) {
		return _modules[msg.sig];
	}
}
