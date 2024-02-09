// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface IDelegatorAccount {

    enum Permission {
        FULL,
        RESTRICTED
    }

    struct NFTInfo {
        uint256 tokenId;
        address nftContract;
    }

    struct DelegateeConfig {
        uint248 expiration;
        Permission permission;
    }

    error AlreadyInitialized();
    error NotOwner(address nftContract, uint256 tokenId, address owner);
    error ReentrancyProhibited();
    error NotDelegator(address caller);
    error NotDelegated(address delegatee);
    error NotApproved(address nftContract, uint256 tokenId);
    error AddressInsufficientBalance(address account);
    error ExpiredDeadline(uint256 deadline);
    error MulticallRuntimeError(string message, uint256 index);
    error PermissionViolation(address delegatee, Permission permission);

    event ERC721Delegated(
        address indexed delegatee,
        NFTInfo indexed info,
        uint256 expiration
    );

    event ERC721Revoked(
        address indexed delegatee,
        NFTInfo info
    );

    event MulticallExecuted(
        address indexed caller,
        bytes[] results
    );

    function delegateERC721(NFTInfo memory info, address delegatee, uint256 expiration, Permission permission) external;

    function revokeERC721(NFTInfo memory info, address delegatee) external;

    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool revertOnFailure
    ) external payable returns (bytes[] memory results);
}
