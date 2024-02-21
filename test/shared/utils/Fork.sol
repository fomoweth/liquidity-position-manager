// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {Constants} from "test/shared/states/Constants.sol";

contract Fork is CommonBase, Constants {
	error UnsupportedChainId(uint256 chainId);

	uint256 mainnetFork;
	uint256 optimismFork;
	uint256 polygonFork;
	uint256 arbitrumFork;

	function setUpForks(bool forkOnBlock) internal {
		if (forkOnBlock) {
			mainnetFork = vm.createFork(vm.envString("RPC_MAINNET"));
			optimismFork = vm.createFork(vm.envString("RPC_OPTIMISM"));
			polygonFork = vm.createFork(vm.envString("RPC_POLYGON"));
			arbitrumFork = vm.createFork(vm.envString("RPC_ARBITRUM"));
		} else {
			mainnetFork = vm.createFork(vm.envString("RPC_MAINNET"), ETHEREUM_FORK_BLOCK);
			optimismFork = vm.createFork(vm.envString("RPC_OPTIMISM"), OPTIMISM_FORK_BLOCK);
			polygonFork = vm.createFork(vm.envString("RPC_POLYGON"), POLYGON_FORK_BLOCK);
			arbitrumFork = vm.createFork(vm.envString("RPC_ARBITRUM"), ARBITRUM_FORK_BLOCK);
		}
	}

	function fork(uint256 chainId) internal returns (uint256) {
		if (chainId == ETHEREUM_CHAIN_ID) vm.selectFork(mainnetFork);
		else if (chainId == OPTIMISM_CHAIN_ID) vm.selectFork(optimismFork);
		else if (chainId == POLYGON_CHAIN_ID) vm.selectFork(polygonFork);
		else if (chainId == ARBITRUM_CHAIN_ID) vm.selectFork(arbitrumFork);
		else revert UnsupportedChainId(chainId);

		return vm.activeFork();
	}
}
