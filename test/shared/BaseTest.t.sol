// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {CurrencyState} from "test/shared/states/CurrencyState.sol";
import {AaveUtils} from "test/shared/utils/AaveUtils.sol";
import {Assertion} from "test/shared/utils/Assertion.sol";
import {Deployer} from "test/shared/utils/Deployer.sol";
import {Fork} from "test/shared/utils/Fork.sol";
import {Utils} from "test/shared/utils/Utils.sol";

abstract contract BaseTest is Test, Assertion, Fork, Deployer, AaveUtils {
	using CurrencyLibrary for Currency;

	function setUp() public virtual;

	function _setUp(uint256 chainId, bool forkOnBlock) internal virtual {
		setUpForks(forkOnBlock);
		fork(chainId);

		setUpCurrencies(chainId);
		setUpAave(chainId);
	}

	function deal(Currency currency, address account, uint256 amount) internal {
		deal(currency.toAddress(), account, amount);
	}
}
