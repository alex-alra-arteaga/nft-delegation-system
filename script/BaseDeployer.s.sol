// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

contract BaseDeployer is Script {
    uint256 internal deployerPrivateKey;

    address internal ownerAddress;

    enum Chains {
        LocalEthereum,
        LocalPolygon,
        LocalArbitrum,
        Sepolia,
        Mumbai,
        ArbitrumSepolia,
        OptimismSepolia,
        Etherum,
        Polygon,
        Arbitrum,
        Optimism
    }

    enum Cycle {
        Dev,
        Test,
        Prod
    }

    /// @dev Mapping of chain enum to rpc url
    mapping(Chains chains => string rpcUrls) public forks;

    /// @dev environment variable setup for deployment
    /// @param cycle deployment cycle (dev, test, prod)
    modifier setEnvDeploy(Cycle cycle) {
        if (cycle == Cycle.Dev) {
            deployerPrivateKey = vm.envUint("LOCAL_DEPLOYER_KEY");
            ownerAddress = vm.envAddress("LOCAL_OWNER_ADDRESS");
        } else if (cycle == Cycle.Test) {
            deployerPrivateKey = vm.envUint("TEST_DEPLOYER_KEY");
            ownerAddress = vm.envAddress("TEST_OWNER_ADDRESS");
        } else {
            deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
            ownerAddress = vm.envAddress("OWNER_ADDRESS");
        }

        _;
    }

    /// @dev environment variable setup for upgrade
    /// @param cycle deployment cycle (dev, test, prod)
    modifier setEnvUpgrade(Cycle cycle) {
        if (cycle == Cycle.Dev) {
            deployerPrivateKey = vm.envUint("LOCAL_DEPLOYER_KEY");
        } else if (cycle == Cycle.Test) {
            deployerPrivateKey = vm.envUint("TEST_DEPLOYER_KEY");
        } else {
            deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        }

        _;
    }

    /// @dev broadcast transaction modifier
    /// @param pk private key to broadcast transaction
    modifier broadcast(uint256 pk) {
        vm.startBroadcast(pk);

        _;

        vm.stopBroadcast();
    }

    constructor() {
        // Local
        forks[Chains.LocalEthereum] =  vm.envString("LOCAL_ETHEREUM_RPC_URL");
        forks[Chains.LocalPolygon] = vm.envString("LOCAL_POLYGON_RPC_URL");
        forks[Chains.LocalEthereum] = vm.envString("LOCAL_ARBITRUM_RPC_URL");

        // Testnet
        forks[Chains.Sepolia] = vm.envString("SEPOLIA_RPC_URL");
        forks[Chains.Mumbai] = vm.envString("MUMBAI_RPC_URL");
        forks[Chains.ArbitrumSepolia] = vm.envString("ARBITRUM_SEPOLIA_RPC_URL");
        forks[Chains.OptimismSepolia] = vm.envString("OPTIMISM_SEPOLIA_RPC_URL");

        // Mainnet
        forks[Chains.Etherum] = vm.envString("ETHERUM_RPC_URL");
        forks[Chains.Polygon] = vm.envString("POLYGON_RPC_URL");
        forks[Chains.Arbitrum] = vm.envString("ARBITRUM_RPC_URL");
        forks[Chains.Optimism] = vm.envString("OPTIMISM_RPC_URL");
    }

    function createSelectFork(Chains chain) public {
        vm.createSelectFork(forks[chain]);
    }
}