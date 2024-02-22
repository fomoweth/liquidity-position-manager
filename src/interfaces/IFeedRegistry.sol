// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface IFeedRegistry {
	event FeedSet(address indexed feed, address indexed base, address indexed quote);

	function latestAnswerETH(Currency base) external view returns (uint256);

	function latestAnswer(Currency base, address quote) external view returns (uint256);

	function getAnswer(Currency base, address quote, uint256 roundId) external view returns (uint256);

	function latestTimestamp(Currency base, address quote) external view returns (uint256);

	function getTimestamp(Currency base, address quote, uint256 roundId) external view returns (uint256);

	function latestRoundData(
		Currency base,
		address quote
	)
		external
		view
		returns (
			uint80 roundId,
			uint256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		);

	function getRoundData(
		Currency base,
		address quote,
		uint80 rid
	)
		external
		view
		returns (
			uint80 roundId,
			uint256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		);

	function latestRound(Currency base, address quote) external view returns (uint256);

	function decimals(Currency base, address quote) external view returns (uint8);

	function description(Currency base, address quote) external view returns (string memory);

	function version(Currency base, address quote) external view returns (uint256);

	function getFeed(Currency base, address quote) external view returns (address aggregator);

	function setFeed(address feed, Currency base, address quote) external;
}
