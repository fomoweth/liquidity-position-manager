// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Currency} from "src/types/Currency.sol";

abstract contract Assertion is Test {
	function assertEq(Currency a, Currency b) internal virtual {
		assertEq(a.toAddress(), b.toAddress());
	}
}
