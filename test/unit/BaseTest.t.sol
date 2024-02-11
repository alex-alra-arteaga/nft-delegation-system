// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {DelegatorRegistry} from "../../src/DelegatorRegistry.sol";
import {IDelegatorRegistry} from "../../src/interfaces/IDelegatorRegistry.sol";
import {DelegatorAccount} from "../../src/DelegatorAccount.sol";
import {IDelegatorAccount} from "../../src/interfaces/IDelegatorAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC721BurnableMock} from "../mocks/ERC721BurnableMock.sol";
import {ERC1155Mock} from "../mocks/ERC1155Mock.sol";
import {EthTransferFailMock} from "../mocks/EthTransferFailMock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Burnable} from "../mocks/interfaces/IERC721Burnable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {INonfungiblePositionManager} from "../mocks/interfaces/INonfungiblePositionManager.sol";

contract BaseTest is Test {
    uint128 internal constant AMOUNT0 = 1195448505167439;
    uint128 internal constant AMOUNT1 = 0;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address internal DELEGATOR = makeAddr("DELEGATOR");
    address internal ERC721A_DELEGATOR = 0xff3879B8A363AeD92A6EABa8f61f1A96a9EC3c1e; // Azuki top holder
    address internal LP_DELEGATOR = 0xD38412c0500d90f0BB5ce2916D0867Bf433E2e59; // Uniswap V3 LP
    address internal DELEGATEE = makeAddr("DELEGATEE");
    address internal RANDOM_USER = makeAddr("RANDOM_USER");
    address internal ATTACKER = makeAddr("ATTACKER");

    INonfungiblePositionManager internal nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    DelegatorAccount internal implementation;
    DelegatorRegistry internal registry;
    IDelegatorAccount internal account;
    IDelegatorAccount internal lpAccount;

    IERC20 internal erc20;
    IERC721Burnable internal erc721;
    IERC721 internal erc721a = IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544); // Azuki ERC721A
    IERC1155 internal erc1155;
    EthTransferFailMock internal ethTransferFail;
    IERC20 internal wBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 internal tBTC = IERC20(0x18084fbA666a33d37592fA2633fD49a74DD93a88);

    // Utilities variables
    IDelegatorAccount.NFTInfo internal erc721Info;
    IDelegatorAccount.NFTInfo internal lpNFTInfo;
    address[] internal lpTargets;
    bytes[] internal lpData;
    uint256[] internal lpValue;
    bytes32 internal proposalHash;
    INonfungiblePositionManager.CollectParams internal calldataParams;
    uint256 internal enoughDeadline;
    uint256 internal expiredDeadline;
    IDelegatorAccount.Permission internal restricted = IDelegatorAccount.Permission.RESTRICTED;
    IDelegatorAccount.Permission internal unrestricted = IDelegatorAccount.Permission.UNRESTRICTED;
    uint256 internal noExpiration;
    uint256 internal oneDayExpiration;

    // Event declarations
    event NewERC721Delegated(
        address indexed delegatee,
        IDelegatorAccount.NFTInfo indexed info,
        uint256 expiration
    );

    event ChangedDelegateeConfig(
        address indexed delegatee,
        IDelegatorAccount.NFTInfo indexed info,
        uint256 expiration,
        IDelegatorAccount.Permission permission
    );

    event ERC721Revoked(
        address indexed delegatee,
        IDelegatorAccount.NFTInfo info
    );

    event MulticallExecuted(
        address indexed caller,
        bytes[] results
    );

    event DelegatorRegistered(address indexed delegator, address indexed account);

    event CalldataProposed(
        bytes32 indexed hash,
        address indexed caller,
        address[] targets,
        bytes[] data,
        uint256[] value,
        IDelegatorAccount.NFTInfo info,
        bool revertOnFailure
    );

    event ProposalStatusChanged(
        bytes32 indexed hash,
        IDelegatorAccount.ProposalStatus indexed status
    );

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);
        vm.rollFork(19197943); // last block number atm of writing

        // Core contracts
        implementation = new DelegatorAccount();
        registry = new DelegatorRegistry(address(implementation));

        // Mocks
        erc20 = new ERC20Mock();
        erc721 = new ERC721BurnableMock("NFTMock", "MCK", DELEGATOR, 10);
        erc1155 = new ERC1155Mock("");
        ethTransferFail = new EthTransferFailMock();

        // Initialize DelegatorAccount
        vm.prank(DELEGATOR);
        account = IDelegatorAccount(registry.registerDelegator());
        vm.startPrank(LP_DELEGATOR);
        lpAccount = IDelegatorAccount(registry.registerDelegator());

        // Init global variables
        erc721Info = IDelegatorAccount.NFTInfo({
            tokenId: 1,
            nftContract: address(erc721)
        });
        lpNFTInfo = IDelegatorAccount.NFTInfo({
            tokenId: 453832,
            nftContract: address(nonfungiblePositionManager)
        });
        lpTargets = new address[](1);
        lpTargets[0] = address(nonfungiblePositionManager);    
        calldataParams = INonfungiblePositionManager.CollectParams({
            tokenId: lpNFTInfo.tokenId,
            recipient: DELEGATEE,
            amount0Max: AMOUNT0,
            amount1Max: AMOUNT1
        });
        lpData = new bytes[](1);
        lpData[0] = abi.encodeWithSelector(INonfungiblePositionManager.collect.selector, calldataParams);
        lpValue = new uint256[](1);
        lpValue[0] = 0;
        proposalHash = keccak256(
            abi.encode(
                DELEGATEE,
                lpTargets,
                lpData,
                lpValue,
                lpNFTInfo,
                false
            )
        );
        uint256 timestamp = 1707567359; // block.timestamp at current block.number, hardcoded since vm.blockTimestamp() is not available at fork tests
        enoughDeadline = timestamp + 1 days;
        expiredDeadline = timestamp - 1 hours;
        oneDayExpiration = timestamp + 1 days;

        // Init proposal scenario
        nonfungiblePositionManager.setApprovalForAll(address(lpAccount), true);
        lpAccount.delegateERC721(
            lpNFTInfo,
            DELEGATEE,
            oneDayExpiration,
            restricted,
            enoughDeadline
        );

        deal(DELEGATOR, 2 ether);
    }
}
