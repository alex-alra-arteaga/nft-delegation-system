// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {DelegatorAccount} from "../src/DelegatorAccount.sol";
import {DelegatorRegistry} from "../src/DelegatorRegistry.sol";
import {BaseDeployer} from "./BaseDeployer.s.sol";

contract DelegatorsDeploymentScript is Script, BaseDeployer {
    address internal prevAccountAddress;
    address internal prevRegistryAddress;
    
    function setUp() public {}
    // RUN with --multi
    function run() public {
        console.log("Starting deployment process");

        // Here we choose to deploy to Mainnet, Testnet or Local
        deployDelegatorTestnet();

        console.log("Deployment completed");
    }

    /// @dev Deploy contracts to mainnet.
    function deployDelegatorMainnet() external setEnvDeploy(Cycle.Prod) {
        Chains[] memory deployForks = new Chains[](4);

        deployForks[0] = Chains.Etherum;
        deployForks[1] = Chains.Polygon;
        deployForks[3] = Chains.Arbitrum;
        deployForks[4] = Chains.Optimism;

        createDeployMultichain(deployForks);
    }

    function deployDelegatorTestnet() public setEnvDeploy(Cycle.Test) {
        Chains[] memory deployForks = new Chains[](4);

        deployForks[0] = Chains.Sepolia;
        deployForks[1] = Chains.Mumbai;
        deployForks[2] = Chains.ArbitrumSepolia;
        deployForks[3] = Chains.OptimismSepolia;

        createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to local.
    function deployDelegatorLocal() external setEnvDeploy(Cycle.Dev) {
        Chains[] memory deployForks = new Chains[](3);

        deployForks[0] = Chains.LocalEthereum;
        deployForks[1] = Chains.LocalPolygon;
        deployForks[2] = Chains.LocalArbitrum;

        createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to selected chains.
    /// @param deployForks The chains to deploy to.
    /// @param cycle The development cycle to set env variables (dev, test, prod).
    function deployDelegatorSelectedChains(
        Chains[] calldata deployForks,
        Cycle cycle
    ) external setEnvDeploy(cycle) {
        createDeployMultichain(deployForks);
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function createDeployMultichain(
        Chains[] memory deployForks
    ) private {
        for (uint256 i; i < deployForks.length; ) {
            console2.log("Deploying Delegator contracts to chain: ", uint(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeployDelegator();

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Function to perform actual deployment.
    function chainDeployDelegator() private broadcast(deployerPrivateKey) {
        console.log("Starting deployment process in Sepolia network");
        
        DelegatorAccount implementation = new DelegatorAccount();
        console.log("DelegatorAccount implementation address: ", address(implementation));

        DelegatorRegistry registry = new DelegatorRegistry(address(implementation));
        console.log("DelegatorRegistry address: ", address(registry));

        // Ideally there should be a check for the consistency of the contract addresses
        require(prevAccountAddress == address(implementation), "Deploying address has unsynced nonces on different chains");
        require(prevRegistryAddress == address(registry), "Deploying address has unsynced nonces on different chains");
    }
}