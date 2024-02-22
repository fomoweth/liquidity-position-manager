// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFeedRegistry} from "src/interfaces/IFeedRegistry.sol";
import {IAddressResolver} from "src/interfaces/IAddressResolver.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Authority} from "src/base/Authority.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

/// @title FeedRegistry
/// @notice Registry of ChainLink Aggregators

contract FeedRegistry is IFeedRegistry, Authority, Initializable {
	using CurrencyLibrary for Currency;

	error FeedNotExists();
	error InvalidQuote();

	mapping(Currency base => mapping(address quote => address feed)) internal _feeds;

	address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address internal constant USD = 0x0000000000000000000000000000000000000348;
	address internal constant MATIC = 0x0000000000000000000000000000000000001010;

	Currency internal immutable WETH;
	Currency internal immutable WBTC;

	IAddressResolver internal resolver;

	constructor(Currency _weth, Currency _wbtc) {
		WETH = _weth;
		WBTC = _wbtc;
	}

	function initialize(address _resolver) external initializer {
		resolver = IAddressResolver(_resolver);
	}

	function latestAnswerETH(Currency base) external view returns (uint256) {
		if (base == WETH) return 1e18;

		address feed = getFeed(base, ETH);
		if (feed != address(0)) return latestAnswer(feed);

		feed = getFeed(base, USD);

		if (feed != address(0)) {
			return derivePrice(latestAnswer(feed), latestAnswer(getFeed(WETH, USD)), 8, 8, 18);
		} else {
			feed = resolveFeed(base, BTC);
			address ETH_BTC = getFeed(WETH, BTC);
			address BTC_ETH = getFeed(WBTC, ETH);

			if (ETH_BTC != address(0)) {
				return derivePrice(latestAnswer(feed), latestAnswer(ETH_BTC), 8, 8, base.decimals());
			} else if (BTC_ETH != address(0)) {
				return derivePrice(latestAnswer(feed), latestAnswer(BTC_ETH), 8, 18, 8);
			} else {
				uint256 baseAnswer = latestAnswer(feed);
				uint256 ethAnswer = latestAnswer(getFeed(WETH, USD));
				uint256 btcAnswer = latestAnswer(getFeed(WBTC, USD));

				if (baseAnswer == 0 || ethAnswer == 0 || btcAnswer == 0) return 0;

				return FullMath.mulDiv(baseAnswer, btcAnswer, ethAnswer);
			}
		}
	}

	function latestAnswer(Currency base, address quote) external view returns (uint256) {
		return latestAnswer(getFeed(base, quote));
	}

	function latestAnswer(address feed) internal view virtual returns (uint256 answer) {
		if (feed == address(0)) revert FeedNotExists();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x50d25bcd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			answer := mload(0x00)

			if slt(answer, 0x00) {
				answer := 0x00
			}
		}
	}

	function getAnswer(Currency base, address quote, uint256 roundId) external view returns (uint256 answer) {
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb5ab58dc00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), roundId)

			if iszero(staticcall(gas(), feed, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			answer := mload(0x00)

			if slt(answer, 0x00) {
				answer := 0x00
			}
		}
	}

	function latestTimestamp(Currency base, address quote) external view returns (uint256 ts) {
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x50d25bcd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			ts := mload(0x00)
		}
	}

	function getTimestamp(Currency base, address quote, uint256 roundId) external view returns (uint256 ts) {
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb5ab58dc00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), roundId)

			if iszero(staticcall(gas(), feed, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			ts := mload(0x00)
		}
	}

	function latestRoundData(
		Currency base,
		address quote
	)
		external
		view
		returns (uint80 roundId, uint256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
	{
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x04)

			mstore(ptr, 0xfeaf968c00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, res, 0xa0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			roundId := mload(res)
			answer := mload(add(res, 0x20))
			startedAt := mload(add(res, 0x40))
			updatedAt := mload(add(res, 0x60))
			answeredInRound := mload(add(res, 0x80))

			if slt(answer, 0x00) {
				answer := 0x00
			}
		}
	}

	function getRoundData(
		Currency base,
		address quote,
		uint80 rid
	)
		external
		view
		returns (uint80 roundId, uint256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
	{
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x9a6fc8f500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), rid)

			if iszero(staticcall(gas(), feed, ptr, 0x24, res, 0xa0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			roundId := mload(res)
			answer := mload(add(res, 0x20))
			startedAt := mload(add(res, 0x40))
			updatedAt := mload(add(res, 0x60))
			answeredInRound := mload(add(res, 0x80))

			if slt(answer, 0x00) {
				answer := 0x00
			}
		}
	}

	function latestRound(Currency base, address quote) external view returns (uint256 roundId) {
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x668a0f0200000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			roundId := mload(0x00)
		}
	}

	function decimals(Currency base, address quote) external view returns (uint8 unit) {
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x313ce56700000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			unit := mload(0x00)
		}
	}

	function description(Currency base, address quote) external view returns (string memory) {
		address feed = resolveFeed(base, quote);

		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x7284e41600000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (string));
	}

	function version(Currency base, address quote) external view returns (uint256 ver) {
		address feed = resolveFeed(base, quote);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x54fd4d5000000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), feed, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			ver := mload(0x00)
		}
	}

	function getFeed(Currency base, address quote) public view returns (address) {
		return _feeds[base][quote];
	}

	function setFeed(address feed, Currency base, address quote) external authorized {
		if (feed == address(0) || base.isZero()) revert Errors.ZeroAddress();
		if (quote != ETH && quote != BTC && quote != USD && quote != MATIC) revert InvalidQuote();

		_feeds[base][quote] = feed;

		emit FeedSet(feed, base.toAddress(), quote);
	}

	function resolveFeed(Currency base, address quote) internal view returns (address feed) {
		feed = getFeed(base, quote);
		if (feed == address(0)) revert FeedNotExists();
	}

	function derivePrice(
		uint256 baseAnswer,
		uint256 quoteAnswer,
		uint8 baseDecimals,
		uint8 quoteDecimals,
		uint8 assetDecimals
	) internal pure returns (uint256) {
		unchecked {
			if (baseAnswer == 0 || quoteAnswer == 0) return 0;

			return
				FullMath.mulDiv(
					scalePrice(baseAnswer, baseDecimals, assetDecimals),
					10 ** assetDecimals,
					scalePrice(quoteAnswer, quoteDecimals, assetDecimals)
				);
		}
	}

	function invertPrice(
		uint256 answer,
		uint8 baseDecimals,
		uint8 quoteDecimals
	) internal pure returns (uint256 inverted) {
		assembly ("memory-safe") {
			switch iszero(answer)
			case 0x00 {
				inverted := div(exp(10, add(baseDecimals, quoteDecimals)), answer)
			}
			default {
				inverted := 0x00
			}
		}
	}

	function scalePrice(
		uint256 answer,
		uint8 feedDecimals,
		uint8 assetDecimals
	) internal pure returns (uint256 scaled) {
		assembly ("memory-safe") {
			switch or(iszero(answer), eq(feedDecimals, assetDecimals))
			case 0x00 {
				switch gt(feedDecimals, assetDecimals)
				case 0x00 {
					scaled := mul(answer, exp(10, sub(assetDecimals, feedDecimals)))
				}
				default {
					scaled := div(answer, exp(10, sub(feedDecimals, assetDecimals)))
				}
			}
			default {
				scaled := answer
			}
		}
	}

	function isAuthorized(address account) internal view virtual override returns (bool) {
		return resolver.getACLManager().isFeedListingAdmin(account);
	}
}
