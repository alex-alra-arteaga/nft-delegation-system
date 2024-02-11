// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {console} from "forge-std/console.sol";
import {AddressSet, LibAddressSet} from "../helpers/AddressSet.sol";
import {IBaseInvariantTest} from "../interfaces/IBaseInvariantTest.t.sol";
import {BaseTimeWarpable} from "../helpers/BaseTimeWarpable.sol";
import {IDelegatorAccount} from "../../../src/interfaces/IDelegatorAccount.sol";
import {IDelegatorRegistry} from "../../../src/interfaces/IDelegatorRegistry.sol";
import {DelegatorAccount} from "../../../src/DelegatorAccount.sol";
import {DelegatorRegistry} from "../../../src/DelegatorRegistry.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721BurnableMock} from "../../mocks/ERC721BurnableMock.sol";
import {IERC721Burnable} from "../../mocks/interfaces/IERC721Burnable.sol";

/// @dev Manages the DelegatorAccount contract and the actors that interact with it
contract AccountHandler is BaseTimeWarpable {
    /// @dev Actor management library
    using LibAddressSet for AddressSet;

    IDelegatorAccount public immutable account;

    address internal DELEGATOR = makeAddr("DELEGATOR");
    address[] internal _targets;

    /// @dev Ghost variables to track the state of the Account contract while the invariants run
    IDelegatorAccount.NFTInfo[] private delegatorsNFTs;
    mapping(address delegatee => IDelegatorAccount.NFTInfo) public delegateeToNFT;
    mapping(address actor => bool) public hasActorSuccededInProhibitedAction;
    bytes32[] public proposalsHashes;

    AddressSet internal _randomUser; /// @dev All the actors that will interact with the Account contract
    AddressSet internal _delegatees; /// @dev All the delegatees that will interact with the Account contract
    address internal currentActor; /// @dev The current actor that is interacting with the Account contract

    mapping(bytes32 => uint256) public calls;

    modifier useActor(uint256 actorIndexSeed) {
        address randUser = _randomUser.rand(actorIndexSeed);
        address randDelegatee = _delegatees.rand(actorIndexSeed);
        currentActor = randUser > randDelegatee ? randUser : randDelegatee;
        _;
        if (randUser == currentActor) {
            hasActorSuccededInProhibitedAction[currentActor] = true;
        }
    }

    /// @dev Counts the number of calls to a function, useful for debugging
    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor(
        IBaseInvariantTest testContract
    ) BaseTimeWarpable(testContract) {
        /// @dev Sets initial actors, this implementation has a fixed number, usually contracts will have functions which can be compatible with creating actors (depositing, minting, etc.)
        /// Use the createActor modifier to create a new actor, use the useActor modifier whith functions that don't use to be the first action an initiating user would have with a protocol (transfer, approve, withdraw...)
        for (uint i = 1; i < 24; i++) {
            _randomUser.add(address(uint160(i * 99))); // prevent collisions
        }
        DelegatorAccount implementation = new DelegatorAccount();
        DelegatorRegistry registry = new DelegatorRegistry(
            address(implementation)
        );
        vm.prank(DELEGATOR);
        account = IDelegatorAccount(registry.registerDelegator());

        _initializeDelegatees();
    }

    // Used to increase entropy by changing the delegatees configs
    function delegateERC721(
        IDelegatorAccount.NFTInfo calldata,
        address actorSeed,
        uint256 expiration,
        IDelegatorAccount.Permission permission,
        uint256 txDeadline
    ) public useActor(uint256(uint160(actorSeed))) countCall("delegateERC721") {
        /// @dev Bound arguments and make assumption for greater run and call success
        IDelegatorAccount.NFTInfo memory nftInfo = delegateeToNFT[_delegatees.rand(uint256(uint160(actorSeed)))];
        
        /// @dev Create specifics for call to succeed (can be done in useActor modifier, but in this case, we need to know the bounded values)

        /// @dev Set currentActor as `msg.sender`
        vm.prank(DELEGATOR);
        /// @dev call the Account contract
        account.delegateERC721(
            nftInfo,
            currentActor,
            expiration,
            permission,
            txDeadline
        );

        /// @dev Function-Level Assertions

        /// @dev Update ghost variables
        delegatorsNFTs.push(nftInfo);
        delegateeToNFT[currentActor] = nftInfo;
    }

    function revokeERC721(
        address delegatee,
        uint256 actorSeed
    ) public useActor(actorSeed) countCall("revokeERC721") {
        IDelegatorAccount.NFTInfo memory nftInfo = delegateeToNFT[delegatee];

        vm.prank(DELEGATOR);
        account.revokeERC721(nftInfo, currentActor);
    }

    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value
    ) public payable useActor(value[0]) countCall("multicall") {
        IDelegatorAccount.NFTInfo memory nftInfo = delegateeToNFT[currentActor];
        uint256 totalValue;
        uint256 surplus;
        for (uint i; i < value.length; i++) {
            totalValue += value[i];
        }
        bound(surplus, 0, totalValue / 2);

        deal(address(this), totalValue + surplus);

        vm.prank(currentActor);
        account.multicall{value: totalValue + surplus}(
            targets,
            data,
            value,
            nftInfo,
            false
        );
    }

    function proposeCalldataExecution(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        IDelegatorAccount.NFTInfo calldata,
        uint256 actorSeed
    ) public useActor(actorSeed) countCall("proposeCalldataExecution") {
        IDelegatorAccount.NFTInfo memory nftInfo = delegateeToNFT[currentActor];
        
        vm.prank(currentActor);
        account.proposeCalldataExecution(
            targets,
            data,
            value,
            nftInfo,
            false
        );

        bytes32 hash = keccak256(abi.encode(currentActor, targets, data, value, nftInfo, false));
        proposalsHashes.push(hash);
    }

    function setProposalStatus(
        uint256 hashIndex,
        IDelegatorAccount.ProposalStatus status,
        uint256 actorSeed
    ) public useActor(actorSeed) countCall("setProposalStatus") {
        uint8 tmpStatus;
        bound(tmpStatus, 2, 3); // 2: Executed, 3: Rejected
        bound(hashIndex, 0, proposalsHashes.length - 1); // Bound hash to a valid index in proposalsHashes
        bytes32 hash = proposalsHashes[hashIndex];
        
        status = IDelegatorAccount.ProposalStatus(tmpStatus);
        
        vm.prank(DELEGATOR);
        account.setProposalStatus(hash, status);
    }

    function executeProposal(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value
    ) public useActor(value[0]) countCall("executeProposal") {
        IDelegatorAccount.NFTInfo memory nftInfo = delegateeToNFT[currentActor];

        bytes32 hash = keccak256(abi.encode(currentActor, targets, data, value, nftInfo, false));
        bool isAlreadyExecuted = IDelegatorAccount.ProposalStatus.EXECUTED == account.proposedCalldata(hash);
        
        vm.prank(currentActor);
        account.executeProposal(
            targets,
            data,
            value,
            nftInfo,
            false
        );
        
        // function-level assertions, see: https://book.getfoundry.sh/forge/invariant-testing#function-level-assertions
        // If the proposal was already executed and managed to execute again, an invariant is broken
        if (isAlreadyExecuted)
            assert(false);
    }

    /// @dev Logs the number of calls each funtion has got
    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("delegateERC721", calls["delegateERC721"]);
        console.log("revokeERC721", calls["revokeERC721"]);
        console.log("multicall", calls["multicall"]);
        console.log(
            "proposeCalldataExecution",
            calls["proposeCalldataExecution"]
        );
        console.log("setProposalStatus", calls["setProposalStatus"]);
        console.log("executeProposal", calls["executeProposal"]);

        // Print ghosts vars, if you want to track the state of any
    }

    // Internals

    function _initializeDelegatees() internal {
        vm.startPrank(DELEGATOR);
        for (uint i; i < 12; i++) {
            // Different ERC721 instances with different tokenIds to add entropy
            address delegatee = address(
                uint160(
                    uint256(keccak256(abi.encode(((i * 99) & block.number))))
                )
            );
            uint256 tokenId = uint256(
                keccak256(abi.encode((block.timestamp | i) % 5000))
            );
            _delegatees.add(delegatee);

            ERC721BurnableMock erc721 = new ERC721BurnableMock{
                salt: bytes32(i)
            }("NFTMock", "MCK", DELEGATOR, 0);

            erc721.mint(DELEGATOR, tokenId);
            erc721.setApprovalForAll(address(account), true);

            IDelegatorAccount.NFTInfo memory nftInfo = IDelegatorAccount
                .NFTInfo({tokenId: tokenId, nftContract: address(erc721)});

            account.delegateERC721(
                nftInfo,
                delegatee,
                uint160(delegatee) % 2 == 0 ? block.timestamp + 3 days : 0, // ~50% of the delegatees have an expiration time
                tokenId % 2 == 0
                    ? IDelegatorAccount.Permission.RESTRICTED
                    : IDelegatorAccount.Permission.UNRESTRICTED, // ~50% of the delegatees have restricted permissions
                block.timestamp + 10 minutes
            );

            delegatorsNFTs.push(nftInfo);
            delegateeToNFT[delegatee] = nftInfo;
        }
    }

    // Helpers

    function forEachActor(function(address) external func) public {
        return _randomUser.forEach(func);
    }

    function forEachDelegatee(function(address) external func) public {
        return _delegatees.forEach(func);
    }

    // Getters

    function getActors() external view returns (address[] memory) {
        return _randomUser.addrs;
    }

    function getDelegatees() external view returns (address[] memory) {
        return _delegatees.addrs;
    }

    function delegatorsNFTsLength() external view returns (uint256) {
        return delegatorsNFTs.length;
    }

    function getDelegatorsNFTs(uint256 index) external view returns (IDelegatorAccount.NFTInfo memory) {
        return delegatorsNFTs[index];
    }
}
