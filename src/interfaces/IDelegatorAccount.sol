// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface IDelegatorAccount {

    enum Permission {
        UNRESTRICTED,
        RESTRICTED
    }

    enum ProposalStatus {
        UNINITIALIZED,
        PENDING,
        APPROVED,
        REJECTED,
        EXECUTED
    }

    struct NFTInfo {
        uint256 tokenId;
        address nftContract;
    }

    struct DelegateeInfo {
        Permission permission;
        mapping(bytes32 hash => uint256 expiration) erc721Expiration;
    }

    error AlreadyInitialized();
    error NotOwner(address nftContract, uint256 tokenId, address owner);
    error ReentrancyProhibited();
    error NotDelegator(address caller);
    error NotDelegated(address delegatee);
    error AlreadyDelegated(address delegatee, NFTInfo info);
    error NotApprovedForAll(address nftContract);
    error ExpiredDeadline(uint256 deadline);
    error CallError(bytes message, uint256 index);
    error PermissionViolation(address delegatee, Permission permission);
    error NotDelegateeWithRestrictedPermission(address delegatee);
    error InvalidProposalStatus(ProposalStatus currentStatus, ProposalStatus status);

    event NewERC721Delegated(
        address indexed delegatee,
        NFTInfo indexed info,
        uint256 expiration
    );

    event ChangedDelegateeConfig(
        address indexed delegatee,
        NFTInfo indexed info,
        uint256 expiration,
        Permission permission
    );

    event ERC721Revoked(
        address indexed delegatee,
        NFTInfo info
    );

    event MulticallExecuted(
        address indexed caller,
        bytes[] results
    );

    event CalldataProposed(
        bytes32 indexed hash,
        address indexed caller,
        address[] targets,
        bytes[] data,
        uint256[] value,
        NFTInfo info,
        bool revertOnFailure
    );

    event ProposalStatusChanged(
        bytes32 indexed hash,
        ProposalStatus indexed status
    );

    function initialize(address _delegator) external;

    function delegateERC721(NFTInfo memory info, address delegatee, uint256 expiration, Permission permission, uint256 deadline) external;

    function revokeERC721(NFTInfo memory info, address delegatee) external;

    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool revertOnFailure
    ) external payable returns (bytes[] memory results);

    function proposeCalldataExecution(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool continueOnFailure
    ) external;

    function setProposalStatus(bytes32 hash, ProposalStatus status) external;

    function executeProposal(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata value,
        NFTInfo calldata info,
        bool continueOnFailure
    ) external payable returns (bytes[] memory results);

    function delegator() external view returns (address);

    function proposedCalldata(bytes32 hash) external view returns (ProposalStatus);

    function getDelegateeInfo(address delegatee, NFTInfo memory info) external view returns (Permission permission, uint256 expiration);

    function isRegisteredNFTContract(address nftContract) external view returns (bool);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4);

}
