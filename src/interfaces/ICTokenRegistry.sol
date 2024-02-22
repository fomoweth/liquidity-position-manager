// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface ICTokenRegistry {
	event CTokenRegistered(address indexed cToken, address indexed underlying);
	event CTokenDeregistered(address indexed cToken, address indexed underlying);

	function COMPTROLLER() external view returns (address);

	function cNATIVE() external view returns (Currency);

	function cETH() external view returns (Currency);

	function WRAPPED_NATIVE() external view returns (Currency);

	function WETH() external view returns (Currency);

	function getCompAddress() external view returns (Currency comp);

	function getPriceOracle() external view returns (address oracle);

	function getAllCTokens() external view returns (Currency[] memory cTokens);

	function getCTokens() external view returns (Currency[] memory cTokens);

	function cTokenToUnderlying(Currency cToken) external view returns (Currency);

	function underlyingToCToken(Currency underlying) external view returns (Currency);

	function isDeprecated(Currency cToken) external view returns (bool status);

	function registerCToken(Currency cToken) external;

	function registerCTokens(Currency[] calldata cTokens) external;

	function deregisterCToken(Currency cToken) external;

	function deregisterCTokens(Currency[] calldata cTokens) external;
}
