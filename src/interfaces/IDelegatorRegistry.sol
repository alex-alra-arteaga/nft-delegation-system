// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface IDelegatorRegistry {
    struct NFTInfo {
        uint256 tokenId;
        address nftContract;
    }

    error NotOwner(address nftContract, uint256 tokenId, address owner);
    error ReentrancyProhibited();
    error NotDelegated(address delegator, address delegatee);
    error NotApproved(address nftContract, uint256 tokenId);
    error AddressInsufficientBalance(address account);


    function delegateERC721(NFTInfo memory info, address delegatee, uint256 expiration) external;

    function revokeERC721(NFTInfo memory info, address delegatee) external;

    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool revertOnFailure
    ) external payable returns (bytes[] memory results);
}
