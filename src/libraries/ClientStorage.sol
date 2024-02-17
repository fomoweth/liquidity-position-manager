// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";

/// @title ClientStorage
/// @notice Contains storage variables for the Client

library ClientStorage {
	event ModuleUpdated(address indexed module, uint8 indexed command, bytes4[] signatures);

	struct State {
		address owner;
		mapping(bytes4 signature => address) modules;
		mapping(address module => bytes4[]) signatures;
	}

	bytes32 private constant SLOT =
		bytes32(uint256(keccak256("lpm.client.storage.state.slot")) - 1) & ~bytes32(uint256(0xff));

	uint8 internal constant ADD = 0;
	uint8 internal constant REMOVE = 1;
	uint8 internal constant REPLACE = 2;

	function configure(address owner) internal {
		State storage state = load();

		if (state.owner != address(0)) revert Errors.ConfiguredAlready();
		if ((state.owner = owner) == address(0)) revert Errors.ZeroAddress();
	}

	function update(
		State storage state,
		uint8 command,
		address module,
		bytes4[] calldata signatures
	) internal {
		if (module == address(0)) revert Errors.InvalidModule();
		if (command > REPLACE) revert Errors.InvalidCommand(command);

		uint256 length = signatures.length;
		uint256 i;

		if (length == 0) revert Errors.EmptyArray();

		while (i < length) {
			bytes4 signature = at(signatures, i);

			if (command == REMOVE) {
				remove(state, module, signature);
			} else {
				address prior = state.modules[signature];

				if (prior != address(0)) {
					if (command == ADD) revert Errors.ExistsAlready();

					remove(state, prior, signature);
				}

				state.modules[signature] = module;
				state.signatures[module].push(signature);
			}

			unchecked {
				i = i + 1;
			}
		}

		emit ModuleUpdated(module, command, signatures);
	}

	function clear(State storage state, address module) internal {
		bytes4[] memory cached = state.signatures[module];
		uint256 length = cached.length;
		uint256 i;

		if (length == 0) revert Errors.InvalidModule();

		while (i < length) {
			delete state.modules[at(cached, i)];

			unchecked {
				i = i + 1;
			}
		}

		delete state.signatures[module];

		emit ModuleUpdated(module, REMOVE, cached);
	}

	function remove(State storage state, address module, bytes4 signature) private {
		bytes4[] memory cached = state.signatures[module];
		uint256 length = cached.length;
		uint256 i;

		while (i < length) {
			if (at(cached, i) == signature) break;

			unchecked {
				i = i + 1;
			}
		}

		if (i == length) revert Errors.InvalidSignature();

		bytes4[] storage signatures = state.signatures[module];
		signatures[i] = signatures[length - 1];
		signatures.pop();

		delete state.modules[signature];
	}

	function load() internal pure returns (State storage s) {
		bytes32 slot = SLOT;

		assembly ("memory-safe") {
			s.slot := slot
		}
	}

	function at(bytes4[] memory signatures, uint256 offset) private pure returns (bytes4 signature) {
		assembly ("memory-safe") {
			signature := mload(add(add(signatures, 0x20), mul(offset, 0x20)))

			if iszero(signature) {
				invalid()
			}
		}
	}
}
