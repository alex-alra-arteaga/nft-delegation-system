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
    mapping(bytes32 hash => address delegator) public hashToDelegator;
    mapping(address delegator => mapping(address delegatee => bool)) public isDelegated;

    modifier onlyERC721Owner(NFTInfo memory info) {
        if (IERC721(info.nftContract).ownerOf(info.tokenId) != msg.sender) {
            revert NotOwner(info.nftContract, info.tokenId, msg.sender);
        }
        _;
    }

    /**
     * @notice Delegate an ERC721 token to a delegatee
     * @dev If NFT changes ownership, the new owner can re-delegate the NFT
     * @dev No check if delegatee is the owner of the NFT since it's not necessary
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     */
    function delegateERC721(NFTInfo memory info, address delegatee) public onlyERC721Owner(info) {
        bytes32 hash = keccak256(abi.encode(info));

        if (IERC721(info.nftContract).getApproved(info.tokenId) != address(this)) {
            revert NotApproved(info.nftContract, info.tokenId, address(this));
        }

        hashToDelegator[hash] = msg.sender;
        isDelegated[msg.sender][delegatee] = true;
    }

    /**
     * @notice Revoke the delegation of an ERC721 token
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     */
    function revokeERC721(NFTInfo memory info, address delegatee) public onlyERC721Owner(info) {
        isDelegated[msg.sender][delegatee] = false;
    }

    /**
     * @notice Intended to be called by the delegatee to do operations with NFT benefits
     * @dev If NFT ownership changes since the delegation, the operation will revert
     */

    // TODO: consider using a reentrancy guard and an option to not revert on failure
    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info
    ) external payable returns (bytes[] memory results) {
        bytes32 hash = keccak256(abi.encode(info));
        address delegator = hashToDelegator[hash];

        if (!isDelegated[delegator][msg.sender]) revert NotDelegated(delegator, msg.sender);
        
        IERC721(info.nftContract).safeTransferFrom(delegator, address(this), info.tokenId);

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            if (targets[i] != info.nftContract) {
                results[i] = Address.functionCallWithValue(targets[i], data[i], value[i]);
            }
        }

        IERC721(info.nftContract).safeTransferFrom(address(this), delegator, info.tokenId);
        return results;
    }
}
