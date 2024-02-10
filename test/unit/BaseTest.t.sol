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
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address internal DELEGATOR = makeAddr("DELEGATOR");
    address internal ERC721A_DELEGATOR = 0xff3879B8A363AeD92A6EABa8f61f1A96a9EC3c1e; // Azuki top holder
    address internal DELEGATEE = makeAddr("DELEGATEE");
    address internal RANDOM_USER = makeAddr("RANDOM_USER");
    address internal ATTACKER = makeAddr("ATTACKER");

    INonfungiblePositionManager internal nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    DelegatorRegistry internal registry;
    IDelegatorAccount internal account;

    IERC20 internal erc20;
    IERC721Burnable internal erc721;
    IERC721 internal erc721a = IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544); // Azuki ERC721A
    IERC1155 internal erc1155;
    EthTransferFailMock internal ethTransferFail;

    // Utilities variables
    IDelegatorAccount.NFTInfo internal erc721Info;
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

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);
        vm.rollFork(19197943); // last block number atm of writing

        // Core contracts
        DelegatorAccount implementation = new DelegatorAccount();
        registry = new DelegatorRegistry(address(implementation));

        // Mocks
        erc20 = new ERC20Mock();
        erc721 = new ERC721BurnableMock("NFTMock", "MCK", DELEGATOR, 10);
        erc1155 = new ERC1155Mock("");
        ethTransferFail = new EthTransferFailMock();

        // Initialize DelegatorAccount
        vm.prank(DELEGATOR);
        account = IDelegatorAccount(registry.registerDelegator());

        // Init global variables
        erc721Info = IDelegatorAccount.NFTInfo({
            tokenId: 1,
            nftContract: address(erc721)
        });
        uint256 timestamp = 1707567359; // block.timestamp at current block.number, hardcoded since vm.blockTimestamp() is not available at fork tests
        enoughDeadline = timestamp + 1 days;
        expiredDeadline = timestamp - 1 hours;
        oneDayExpiration = timestamp + 1 days;

        deal(DELEGATOR, 100 ether);
    }
}
