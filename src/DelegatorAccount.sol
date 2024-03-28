// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IDelegatorAccount} from "./interfaces/IDelegatorAccount.sol";

/**
 * @title DelegatorAccount
 * @author Alex Arteaga
 * @notice This contract is intended to be used as the implementation for each delegator to delegate assets
 */
contract DelegatorAccount is IDelegatorAccount {
    bool private _initialized;
    address public delegator;

    mapping(address delegatee => DelegateeInfo) private delegateeToNFT;
    mapping(address nftContract => bool isRegistered) public isRegisteredNFTContract;
    mapping(bytes32 proposedHash => ProposalStatus) public proposedCalldata;

    /**
     * @notice Checks if the caller is the delegator
     */
    modifier onlyDelegator() {
        if (delegator != msg.sender) revert NotDelegator(msg.sender);
        _;
    }

    /**
     * @notice Initialize the contract with the delegator address, only callable by the registry contract
     * @param _delegator Address of the delegator
     */
    function initialize(address _delegator) external {
        if (_initialized) revert AlreadyInitialized();
        delegator = _delegator;

        _initialized = true;
    }

    /**
     * @notice Delegate an ERC721 token to a delegatee
     * @notice The expiration is optional, if set to prior than current unix timestamp, the delegation will be permanent
     * @notice Only callable by the delegator
     * @dev If NFT changes ownership, the new owner can re-delegate the NFT
     * @dev No check if delegator is the owner of the NFT, since the `isApprovedForAll` check is enough
     * @dev Deadline is used to prevent pending transactions to be executed after a certain time, either through malicious intent by mempool manipulator, or by accident
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     * @param expiration Unix timestamp of the delegation expiration
     * @param permission Permission of the delegatee, can be `UNRESTRICTED` (0) or `RESTRICTED` (1)
     * @param txDeadline Unix timestamp of the deadline
     */
    function delegateERC721(
        NFTInfo memory info,
        address delegatee,
        uint256 expiration,
        Permission permission,
        uint256 txDeadline
    ) public onlyDelegator {
        if (txDeadline < block.timestamp) revert ExpiredDeadline(txDeadline);
        if (!IERC721(info.nftContract).isApprovedForAll(delegator, address(this))) {
            revert NotApprovedForAll(info.nftContract);
        }

        bytes32 hash = keccak256(abi.encode(info));
        bool exists = delegateeToNFT[delegatee].erc721Expiration[hash] != 0;

        delegateeToNFT[delegatee].erc721Expiration[hash] = expiration >=
            block.timestamp
            ? expiration
            : type(uint256).max;
        delegateeToNFT[delegatee].permission = permission;

        if (!isRegisteredNFTContract[info.nftContract])
            isRegisteredNFTContract[info.nftContract] = true;

        if (exists)
            emit ChangedDelegateeConfig(
                delegatee,
                info,
                expiration,
                permission
            );
        else emit NewERC721Delegated(delegatee, info, expiration);
    }

    /**
     * @notice Revoke the delegation of an ERC721 token
     * @notice Only callable by the delegator
     * @dev Set to 1 to save gas if delegatee is re-delegated
     * @dev Check if delegatee address is an actual delegatee is redundant
     * @dev Doesn't check for NFT ownership since in cases a delegatee is compromised, the delegator can revoke the delegation before the delegatee gains any benefit
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     */
    function revokeERC721(
        NFTInfo memory info,
        address delegatee
    ) public onlyDelegator {
        bytes32 hash = keccak256(abi.encode(info));

        delegateeToNFT[delegatee].erc721Expiration[hash] = 1;

        emit ERC721Revoked(delegatee, info);
    }

    /**
     * @notice Intended to be called by the delegatee to do operations with NFT benefits
     * @notice It is recommended to use `setApprovalForAll` instead of `approve` to avoid reverts
     * @dev If it was currently registered with `approve`, and not `setApprovalForAll`, any NFT ownership changes since the delegation will make the operation revert
     * @dev The Ether callback is useful if there where a miscalculation between Σ of value[] and msg.value OR if the NFT benefit is ether!
     * @dev Also if continueOnFailure is true, an call sending ether reverts, eth would be stuck in this contract
     * @param targets Addresses of the addresses to call
     * @param data Calldata to send to the contracts
     * @param value Ether to send to the addresses
     * @param info NFT we want to flash borrow
     * @param continueOnFailure If true, the execution will continue even if a call fails
     */
    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool continueOnFailure
    ) external payable returns (bytes[] memory results) {
        uint256 prevBalance = address(this).balance - msg.value;
        bytes32 hash = keccak256(abi.encode(info));
        uint256 expiration = delegateeToNFT[msg.sender].erc721Expiration[hash];
        Permission permission = delegateeToNFT[msg.sender].permission;

        return _multicall(
            targets,
            data,
            value,
            info,
            continueOnFailure,
            expiration,
            permission,
            prevBalance
        );
    }

    /**
     * @notice Propose a calldata execution
     * @notice Endpoint for delegatees with `RESTRICTED` permission to propose calldata executions that involve interactions with NFT contracts registered by the delegator
     * @dev Checks if msg.sender is a delegatee and if the permission is `RESTRICTED` in same if statement
     * @dev We don't want to have UNRESTRICTED delegatees to propose calldata executions, since they can do it directly with same benefits
     * @dev If certain caller is not a delegatee with a delegated NFT, it will revert with NotDelegated
     * @param targets Addresses of the contracts to call
     * @param data Calldata to send to the contracts
     * @param value Ether to send to the addresses
     * @param info NFT we want to flash borrow
     * @param continueOnFailure If true, the proposal will continue even if a call fails
     */
    function proposeCalldataExecution(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool continueOnFailure
    ) public {
        (Permission permission, uint256 expiration) = this.getDelegateeInfo(msg.sender, info);

        if (expiration <= block.timestamp) revert NotDelegated(msg.sender);
        if (permission != Permission.RESTRICTED) revert NotDelegateeWithRestrictedPermission(msg.sender);

        bytes32 hash = keccak256(abi.encode(msg.sender, targets, data, value, info, continueOnFailure));

        proposedCalldata[hash] = ProposalStatus.PENDING;

        emit CalldataProposed(hash, msg.sender, targets, data, value, info, continueOnFailure);
    }


    /**
     * @notice Set the status of a proposal
     * @notice Only callable by the delegator
     * @notice The proposal must be `PENDING` to be approved or rejected
     * @notice Once a proposal is approved or rejected, it cannot be changed
     * @param hash Hash of the proposal calldata
     * @param status New status of the proposal, can only be `APPROVED` or `REJECTED`
     */
    function setProposalStatus(bytes32 hash, ProposalStatus status) public onlyDelegator {
        ProposalStatus currentStatus = proposedCalldata[hash];
        if (currentStatus != ProposalStatus.PENDING || (status != ProposalStatus.APPROVED && status != ProposalStatus.REJECTED))
            revert InvalidProposalStatus(currentStatus, status);

        proposedCalldata[hash] = status;

        emit ProposalStatusChanged(hash, status);
    }

    /**
     * @notice Execute a proposal
     * @dev The proposal must be `APPROVED` to be executed
     * @dev The expiration is checked before the execution in the _multicall function to avoid unintended consequences
     * @param targets Addresses of the addresses to call
     * @param data Calldata to send to the contracts
     * @param value Ether to send to the addresses
     * @param info NFT we want to flash borrow
     * @param continueOnFailure If true, the execution will continue even if a call fails
     */
    function executeProposal(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool continueOnFailure
    ) public payable returns (bytes[] memory) {
        uint256 prevBalance = address(this).balance - msg.value;
        bytes32 nftHash = keccak256(abi.encode(info));
        uint256 expiration = delegateeToNFT[msg.sender].erc721Expiration[nftHash];
        bytes32 proposalHash = keccak256(abi.encode(msg.sender, targets, data, value, info, continueOnFailure));

        if (proposedCalldata[proposalHash] != ProposalStatus.APPROVED)
            revert NotDelegated(msg.sender);

        proposedCalldata[proposalHash] = ProposalStatus.EXECUTED;

        return _multicall(targets, data, value, info, continueOnFailure, expiration, Permission.UNRESTRICTED, prevBalance);        
    }

    function _multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool continueOnFailure,
        uint256 expiration,
        Permission permission,
        uint256 prevBalance
    ) internal returns (bytes[] memory results) {
        if (expiration <= block.timestamp) revert NotDelegated(msg.sender);

        IERC721(info.nftContract).safeTransferFrom(
            delegator,
            address(this),
            info.tokenId
        );

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            if (
                permission == Permission.RESTRICTED &&
                isRegisteredNFTContract[targets[i]]
            ) {
                revert PermissionViolation(msg.sender, permission);
            }

            (bool success, bytes memory returnData) = targets[i].call{
                value: value[i]
            }(data[i]);
            if (!success && !continueOnFailure)
                revert CallError(returnData, i);

            results[i] = returnData;
        }

        IERC721(info.nftContract).safeTransferFrom(
            address(this),
            delegator,
            info.tokenId
        );

        if (address(this).balance > prevBalance) {
            (bool success,) = msg.sender.call{value: address(this).balance - prevBalance}("");
            if (!success) revert CallError("Failed to send ether", data.length);
        }

        emit MulticallExecuted(msg.sender, results);
    }

    function getDelegateeInfo(address delegatee, NFTInfo memory info)
        external
        view
        returns (Permission permission, uint256 expiration)
    {
        bytes32 hash = keccak256(abi.encode(info));

        return (
            delegateeToNFT[delegatee].permission,
            delegateeToNFT[delegatee].erc721Expiration[hash]
        );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
