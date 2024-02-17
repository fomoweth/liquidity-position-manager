// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface IClient {
	function register(uint8 command, address module, bytes4[] calldata signatures) external;

	function deregister(address module) external;

	function withdraw(Currency currency, uint256 amount) external;

	function owner() external view returns (address);
}
