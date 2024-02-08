// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IDelegatorRegistry.sol";

/**
 * @title DelegatorRegistry
 * @author Alex Arteaga, future Openfort Blockchain Engineer
 * @notice This contract is intended to be used as a registry for multi assets delegations
 */
contract DelegatorRegistry is IDelegatorRegistry {
    uint8 private _lock = 1;
    mapping(bytes32 hash => address delegator) public hashToDelegator;
    mapping(address delegator => mapping(address delegatee => uint256 expiration))
        public delegateeExpiration;

    modifier onlyERC721Owner(NFTInfo memory info) {
        if (IERC721(info.nftContract).ownerOf(info.tokenId) != msg.sender)
            revert NotOwner(info.nftContract, info.tokenId, msg.sender);
        _;
    }

    /**
     * @notice Prevents a contract from calling itself, directly or indirectly
     * @dev Zero to non-zero transitions are 4 times more expensive than non-zero to non-zero transitions
     */
    modifier nonReentrant() {
        if (_lock == 2) revert ReentrancyProhibited();
        _lock = 2;
        _;
        _lock = 1;
    }

    /**
     * @notice Delegate an ERC721 token to a delegatee
     * @dev If NFT changes ownership, the new owner can re-delegate the NFT
     * @dev No check if delegatee is the owner of the NFT since it's not necessary
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     */
    function delegateERC721(
        NFTInfo memory info,
        address delegatee,
        uint256 expiration
    ) public onlyERC721Owner(info) nonReentrant {
        bytes32 hash = keccak256(abi.encode(info));

        if (
            !IERC721(info.nftContract).isApprovedForAll(msg.sender, delegatee)
        ) {
            revert NotApproved(info.nftContract, info.tokenId);
        }

        hashToDelegator[hash] = msg.sender;
        delegateeExpiration[msg.sender][delegatee] = expiration >=
            block.timestamp
            ? expiration
            : type(uint256).max;
    }

    /**
     * @notice Revoke the delegation of an ERC721 token
     * @dev Set to 1 to save gas if delegatee is re-delegated
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     */
    function revokeERC721(
        NFTInfo memory info,
        address delegatee
    ) public onlyERC721Owner(info) nonReentrant {
        delegateeExpiration[msg.sender][delegatee] = 1;
    }

    /**
     * @notice Intended to be called by the delegatee to do operations with NFT benefits
     * @dev If NFT ownership changes since the delegation, the operation will revert
     */
    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool revertOnFailure
    ) external payable nonReentrant returns (bytes[] memory results) {
        bytes32 hash = keccak256(abi.encode(info));
        address delegator = hashToDelegator[hash];

        if (delegateeExpiration[delegator][msg.sender] <= block.timestamp)
            revert NotDelegated(delegator, msg.sender);

        IERC721(info.nftContract).safeTransferFrom(delegator, address(this), info.tokenId);

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            if (targets[i] != info.nftContract) {
                (bool success, bytes memory returnData) = targets[i].call{value: value[i]}(data[i]);
                if (revertOnFailure && !success) revert(string(returnData));
                results[i] = returnData;
            }
        }

        IERC721(info.nftContract).safeTransferFrom(address(this), delegator, info.tokenId);
        return results;
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
