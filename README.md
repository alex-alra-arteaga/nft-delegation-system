# NFT Delegation System, a.k.a FortDel

- FortDel is a non-costudial ERC721 delegation system that allows delegators the degree of flexibility and security they desire to their delegatees.   
- FortDel is a new primitive for Account Abstraction wallets, it is interoperable with any type of Account Abstraction, ERC-6551 and EOA wallets.   
- The protocol is designed to be a simple, immutable, and trust-minimized base layer that allows for a wide variety of other features to be built on top.   
- It provides different delegatees permissions and restricted functionalities at the discretion of the delegator.   
- FortDel also offers a convenient developer experience, with a multichain registry and base implementation present at the same address on all chains.   

## Table of Contents

- [Repository Structure](#repository-structure)
- [Technical Documentation](#technical-documentation)
  - [Protocol Overview](#protocol-overview)
  - [FortDel High Level Sequence](#fortdel-high-level-sequence)
  - [Delegator Account Actions](#delegator-account-actions)
  - [Security Considerations](#security-considerations)
    - [Testing Choices](#testing-choices)
  - [Future Features](#future-features)
- [Multichain Contract Addresses](#multichain-contract-addresses)
- [Usage](#usage)
  - [Installation](#installation)
  - [Build](#build)
  - [Test](#test)
  - [Deploy & Verification](#deploy--verification)
  - [Gas Snapshots](#gas-snapshots)
  - [Help](#help)

## Repository Structure

The codebase is organized as follows:
- docs/: Contains the developer thought process since the beginning of the project. Design choices, changes, security considerations and future features have been documented on the go.
- src/: Contains the 2 main contracts, DelegatorsRegistry and DelegatorAccount, and the interfaces they implement.
- scripts/: Contains the multichain deployment scripts.
- test/: Contains the tests for the 2 main contracts.
    - test/unit/: Unit testing with 100% coverage, designed following the Branching Tree Technique, all branches and state transitions are tested under no developer assumptions since BTT is done previously the code writting begins. All tests are run with fork testing Ethereum mainnet and staging real case scenarios, e.g. collecting UniswapV3 liquidity.
    - test/invariants/: Invariants testing, specifically 'stateful fuzzing', since the invariants are put under breakage with changing program and environment states. Invariants are tested every run. In my case run it for 100_000_000 times with no breakage.
    - test/symbolic/: Leveraging Halmos, a symbolic execution engine to formally verify/prove the correctness of the DelegatorAccount to explore paths that'd cause the delegator to lose NFTs ownership.
-env.example: Contains the environment variables that are used in the deployment scripts and fork testing.

## Technical Documentation

### Protocol Overview

There are 2 main contracts in FortDel protocol:
- DelegatorAccount: It is the intermediary contract between the delegator and the delegatee. It is the endpoint for the delegator to approve their NFTs benefits to the delegatee. Has 2 possible paths to execute transactions with the NFT ownership as msg.sender, the direct one, where the delegators applied restrictions are enforced or not, and the indirect one, which involves a 2 step proposal process in order to execute any transaction.
- DelegatorsRegistry: It is a multichain minimal proxy registry which stores the DelegatorAccount implementation address. It's the endpoint for delegators to create their own DelegatorAccount.

### FortDel High Level Sequence

1. [Delegator creates a DelegatorAccount via DelegatorsRegistry.](docs/sequences/creation-registry.md)
2. [Delegator approves NFT to Account and registers delegatee.](docs/sequences/delegation-account.md)
3. [Delegatee proposes a transaction to DelegatorAccount.](docs/sequences/proposal-process-account.md)
4. [Delegatee (with UNRESTRICTED permission) collects NFTs benefits.](docs/sequences/usecase-account.md)

### Delegator Account Actions

| Role          | Action                       | Expected Impact                                                                           |
|---------------|------------------------------|-------------------------------------------------------------------------------------------|
| Registry     | `initialize`                 | Initializes the contract with delegator's address, setting up the Delegator address.     |
| Delegator     | `delegateERC721`             | Delegates an ERC721 token to a specified delegatee with optional expiration and permission. |
| Delegator     | `revokeERC721`               | Revokes an existing delegation of an ERC721 token from a delegatee.                      |
| Delegatee     | `multicall`                  | Executes multiple calls in a single transaction, potentially involving NFT operations.    |
| Delegatee     | `proposeCalldataExecution`   | Proposes a calldata execution for operations requiring unrestricted permissions.            |
| Delegator     | `setProposalStatus`          | Updates the status of a proposed calldata execution to approved or rejected.              |
| Delegatee     | `executeProposal`            | Executes an approved proposal containing one or more calls.                               |
| Any           | `getDelegateeInfo`           | Retrieves delegation information (permission and expiration) for a delegatee.             |
| Any           | `onERC721Received`           | Implements the ERC721 token receiver interface to allow the contract to receive tokens.   |


### Security Considerations

As far as it is known, the only attack vector are delegatees with UNRESTRICTED permissions. Since the Delegator is mandatated to 'setApprovalForAll' to the `DelegatorAccount`, if multicall targets the NFT contract, it can `transferFrom` all tokens of that respective collection to the delegatee. This is a known attack vector, and the delegator should be aware of the risks of delegating to a delegatee with UNRESTRICTED permissions.   
Such a permission should be used only for trusted delegatees.   

There are 2 solutions to this attack vector:   
1. The approval is done via the function `approve`, which works for a single token, but is cleared after a transfer, so the delegator should approve the token again after each multicall, which is impractical.   
2. The DelegatorAccount is deployed per a tokenId basis, not by per delegator basis, so the delegator can have a different DelegatorAccount for each NFT, and then the delegatee can only interact with the NFT that the delegator has approved to the delegatee. This has clear gas cost inconveniences.   

That is why the current design is to have a proposal process, where the delegatee can propose a transaction to the delegator, and the delegator via off-chain simulation can verify there is no malicious intent (checking no `transferFrom` calls to the delegatee), and then approve the proposal, and then the delegatee can execute the proposal, which will be a safe way to interact with the NFT.   
Such a simulator would be very simple, just checking the calldata and the multicall targets, and then the delegator can sign the proposal, and the delegatee can execute it.   
This can be done on-chain, but it is a great gas cost and complexity I'm not willing to take for this technical test. But I'm open to study its safety and gas cost in the future if Openfort team is interested.   

For more design trade-offs and choices, refer to the [docs/](docs/) directory. They are the docs/thoughts I have written since the beginning of the project.   

#### Testing Choices

Over all the testing process I know, decided to use the following:   
- Unit Testing: They are a must and are very helpful to validate the code correctness in the architecture design process. Once the architecture minimal template is done I challenge my assumption by writing a tree with every action each branch/transition is supposed to do.   
- Invariants Testing: Unit testing are stateless and don't cover transitions and scenarios that you can't think of. With a good invariant testing suite you cover most of the possible state scenarios and transitions.   
But I have to say that this isn't the best of the contracts to do invariants testing, since it heavily depends on interactions with any other contract (through the multicalls), that's the reason I have continued with the following test type.   
- Symbolic Testing: It is the best way to prove the correctness of the contract, since it explores all the possible paths and state transitions, and it is the only way to prove the correctness of the contract (if the tests and `vm.assume` assumptions are correctly writed). I have used Halmos, a symbolic execution engine, to formally verify/prove the correctness of the DelegatorAccount to explore paths that'd cause the delegator to lose NFTs ownership.   
Even though, since it is the second time I use Halmos and counterexamples are not very clear, it has been a helpful tool to prove the correctness of the contract.   

### Future Features

1. Since the primitive that FortDel offers is for accounts to flashloan NFTs, it is possible to build an economic layer where the delegator can charge a fee for the delegation of the NFTs.
This fee can be charged by a constant and/or variable payment, e.g. via Sablier, leveraging FortDel time-expiring delegations. Can also leverage OpenForts paymaster.
2. A simple and powerful feature is to permit the restricted delegatees proposals with delegators off-chain signatures, e.g. via EIP-712.
3. ERC1155 support, which would be mainly adding an `onERC1155Received` function. 
4. ERC20 support, which would be mainly adding the [ERC-3156](https://eips.ethereum.org/EIPS/eip-3156) and a type(uint256).max approval to the DelegatorAccount.
5. Finetuned implementation for `ERC6551OpenfortAccount`.

## Multichain Contract Addresses

| Chain             | DelegatorsRegistry Address                                                                                   | DelegatorAccount Address                                                                                     |
|-------------------|---------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| Sepolia           | [0x308eedd6f1e96b46b640bf67324a063b1cd98d00](https://sepolia.etherscan.io/address/0x308eedd6f1e96b46b640bf67324a063b1cd98d00) | [0xe01906d01515dC0b76846AbFeAb9F78CE47FC054](https://sepolia.etherscan.io/address/0xe01906d01515dC0b76846AbFeAb9F78CE47FC054) |
| Mumbai            | [0x308eedd6f1e96b46b640bf67324a063b1cd98d00](https://mumbai.polygonscan.com/address/0x308eedd6f1e96b46b640bf67324a063b1cd98d00) | [0xe01906d01515dC0b76846AbFeAb9F78CE47FC054](https://mumbai.polygonscan.com/address/0xe01906d01515dC0b76846AbFeAb9F78CE47FC054) |
| Optimism Sepolia  | [0x308eedd6f1e96b46b640bf67324a063b1cd98d00](https://sepolia-optimistic.etherscan.io/address/0x308eedd6f1e96b46b640bf67324a063b1cd98d00) | [0xe01906d01515dC0b76846AbFeAb9F78CE47FC054](https://sepolia-optimistic.etherscan.io/address/0xe01906d01515dC0b76846AbFeAb9F78CE47FC054) |
| Arbitrum Sepolia  | [0x308eedd6f1e96b46b640bf67324a063b1cd98d00](https://sepolia.arbiscan.io/address/0x308eedd6f1e96b46b640bf67324a063b1cd98d00) | [0xe01906d01515dC0b76846AbFeAb9F78CE47FC054](https://sepolia.arbiscan.io/address/0xe01906d01515dC0b76846AbFeAb9F78CE47FC054) |


Since DelegatorRegistry is intended to be heavily used, I would mine and address that its create2 results in a contract with some leadings 0s to minimize call gas costs.

## Usage

Make sure to be running Forge version or close.
forge 0.2.0 (b174c3a 2024-02-09T00:16:22.953958126Z)

### Installation

Forge:
```shell
$ forge install
# If something breaks, try to install the dependencies manually
$ forge install OpenZeppelin/openzeppelin-contracts@17a8955cd8ed2c9a269421a11c2e2774b796e305 --no-commit
$ forge install a16z/halmos-cheatcodes --no-commit
```

Halmos:
```shell
$ pip install halmos
```

If you have any issue with Halmos installation, refer to its [README](https://github.com/a16z/halmos/blob/main/docs/getting-started.md#0-install-halmos).

### Build

```shell
$ forge build
```

### Test

The Halmos `setUp()` will be shown failing, but it is expected, since it is only callable by halmos command.

IMPORTANT! You have to set your `MAINNET_RPC_URL` in the `.env` file to run the tests. You have a `.env.example` file to guide you.

```shell
# Run all tests
$ forge test

# Run a specific file tests
$ forge test --mp test/unit/DelegatorAccount/06-executeProposal/executeProposal.t.sol

# Run a specific test
$ forge test --mt test_WhenTheTokenIsNotApprovedForTheDelegate

# Run Halmos symbolic tests
$ halmos --function test_noDelegatorNFTloss
```

### Deploy & Verification

RPC_URLs for desired networks should be set in the `.env` file.
PRIVATE_KEY should be set in the `.env` file.
The PRIVATE_KEY account should have the same nonce in all networks to correctly deploy the contracts at the same address.

```shell
$ forge script script/Deployment.s.sol:DelegatorsDeploymentScript --broadcast --verify --legacy --etherscan-api-key <your_etherscan_api_key>
```

Remaining verification:
```shell
forge verify-contract <contract_address> <contract_path> --etherscan-api-key <your_etherscan_api_key> --chain <network>
```

### Gas Snapshots

Written to `.gas.snapshot` file.

```shell
$ forge snapshot
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
