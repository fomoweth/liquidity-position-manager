// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Encoder {
	function toBytes32(string memory value) internal pure returns (bytes32) {
		return bytes32(bytes(value));
	}

	function toId(string memory value) internal pure returns (bytes32) {
		return keccak256(bytes(value));
	}

	function bytes32ToString(bytes32 x) internal pure returns (string memory) {
		uint256 length = 32;
		uint256 charCount;
		uint256 i;

		bytes memory bytesString = new bytes(length);

		while (i < length) {
			bytes1 char = x[i];

			if (char != 0) {
				bytesString[charCount] = char;

				unchecked {
					charCount = charCount + 1;
				}
			}

			unchecked {
				i = i + 1;
			}
		}

		bytes memory bytesStringTrimmed = new bytes(charCount);
		i = 0;

		while (i < charCount) {
			bytesStringTrimmed[i] = bytesString[i];

			unchecked {
				i = i + 1;
			}
		}

		return string(bytesStringTrimmed);
	}
}
