// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/IDelegatorAccount.sol";

/**
 * @title DelegatorAccount
 * @author Alex Arteaga, future Openfort Blockchain Engineer
 * @notice This contract is intended to be used as the implementation for each delegator to delegate assets
 */
contract DelegatorAccount is IDelegatorAccount {
    uint8 private _lock = 1;
    bool private _initialized;

    address public delegator;

    mapping(address delegatee => DelegateeConfig config)
        public delegateeToConfig;
    mapping(address nftContract => bool isApproved)
        public isApprovedNFTContract;

    /**
     * @notice Checks if the caller is the delegator
     */
    modifier onlyDelegator() {
        if (delegator != msg.sender) revert NotDelegator(msg.sender);
        _;
    }

    /**
     * @notice Checks if the caller is the owner of the NFT
     */
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

    function initialize(address _delegator) external {
        if (_initialized) revert AlreadyInitialized();

        delegator = _delegator;

        _initialized = true;
    }

    /**
     * @notice Delegate an ERC721 token to a delegatee
     * @notice The expiration is optional, if set to prior than current unix timestamp, the delegation will be permanent
     * @dev If NFT changes ownership, the new owner can re-delegate the NFT
     * @dev No check if delegatee is the owner of the NFT since it's not necessary
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     */
    function delegateERC721(
        NFTInfo memory info,
        address delegatee,
        uint248 expiration,
        Permission permission
    ) public onlyDelegator onlyERC721Owner(info) nonReentrant {
        if (!IERC721(info.nftContract).isApprovedForAll(delegator, delegatee)) {
            revert NotApproved(info.nftContract, info.tokenId);
        }

        delegateeToConfig[delegatee] = DelegateeConfig({
            expiration: expiration >= block.timestamp
                ? expiration
                : type(uint248).max,
            permission: permission
        });

        if (!isApprovedNFTContract[info.nftContract])
            isApprovedNFTContract[info.nftContract] = true;

        emit ERC721Delegated(delegatee, info, expiration);
    }

    /**
     * @notice Revoke the delegation of an ERC721 token
     * @dev Set to 1 to save gas if delegatee is re-delegated
     * @dev Check if delegatee address is an actual delegatee is redundant
     * @dev Doesn't has onlyERC721Owner modifier since in cases a delegatee is compromised, the delegator can revoke the delegation before the delegatee gains any benefit
     * @param info Information of the NFT
     * @param delegatee Address of the delegatee
     */
    function revokeERC721(
        NFTInfo memory info,
        address delegatee
    ) public onlyDelegator nonReentrant {
        delegateeToConfig[delegatee].expiration = 1;

        emit ERC721Revoked(delegatee, info);
    }

    /**
     * @notice Change the configuration of a delegateewa
     * @dev Doesn't has onlyERC721Owner modifier since in cases a delegatee is compromised, the delegator can revoke the delegation before the delegatee gains any benefit
     * @dev Deadline is used to prevent pending transactions to be executed after a certain time, either through malicious intent by mempool manipulator, or by accident
     * @param delegatee Address of the delegatee
     * @param expiration Unix timestamp of the expiration
     * @param permission Permission of the delegatee
     * @param deadline Unix timestamp of the deadline
     */
    function changeDelegateeConfig(
        address delegatee,
        uint248 expiration,
        Permission permission,
        uint256 deadline
    ) public onlyDelegator nonReentrant {
        if (deadline < block.timestamp) revert ExpiredDeadline(deadline);

        delegateeToConfig[delegatee] = DelegateeConfig({
            expiration: expiration >= block.timestamp
                ? expiration
                : type(uint248).max,
            permission: permission
        });
    }

    /**
     * @notice Intended to be called by the delegatee to do operations with NFT benefits
     * @notice It is recommended to use `setApprovalForAll` instead of `approve` to avoid reverts
     * @dev If it was currently registered with `approve`, and not `setApprovalForAll`, any NFT ownership changes since the delegation will make the operation revert
     */
    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool revertOnFailure
    ) external payable nonReentrant returns (bytes[] memory results) {
        DelegateeConfig memory config = delegateeToConfig[msg.sender];

        if (config.expiration <= block.timestamp)
            revert NotDelegated(msg.sender);

        IERC721(info.nftContract).safeTransferFrom(delegator, address(this), info.tokenId);

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            if (
                config.permission == Permission.RESTRICTED &&
                isApprovedNFTContract[targets[i]]
            ) {
                revert PermissionViolation(msg.sender, config.permission);
            }

            (bool success, bytes memory returnData) = targets[i].call{
                value: value[i]
            }(data[i]);

            if (revertOnFailure && !success) revert MulticallRuntimeError(string(returnData), i);
            
            results[i] = returnData;
        }

        IERC721(info.nftContract).safeTransferFrom(address(this), delegator, info.tokenId);

        emit MulticallExecuted(msg.sender, results);

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
