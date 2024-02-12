// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Test} from "forge-std/Test.sol";
import {DelegatorAccount} from "../../src/DelegatorAccount.sol";
import {DelegatorRegistry} from "../../src/DelegatorRegistry.sol";
import {IDelegatorAccount} from "../../src/interfaces/IDelegatorAccount.sol";
import {IDelegatorRegistry} from "../../src/interfaces/IDelegatorRegistry.sol";
import {ERC721BurnableMock} from "../mocks/ERC721BurnableMock.sol";
import {IERC721Burnable} from "../mocks/interfaces/IERC721Burnable.sol";
import {console} from "forge-std/console.sol";

contract DelegatorAccountSymTest is SymTest, Test {
    DelegatorRegistry registry;
    IDelegatorAccount account;
    IERC721Burnable internal erc721;
    
    IDelegatorAccount.NFTInfo[] delegatorsNfts;

    address delegator;
    address delegatee;
    uint256 tokenId;
    uint256 expiration;
    uint8 permission;
    uint256 txDeadline;

    function setUp() public {
        delegator = address(0x100);
        delegatee = svm.createAddress('delegatee');
        tokenId = svm.createUint256('tokenId');
        expiration = svm.createUint256('expiration');
        permission = uint8(svm.createUint(8, 'permission'));
        txDeadline = svm.createUint256('txDeadline');

        vm.assume(delegator != delegatee);
        vm.assume(delegator != address(0));
        vm.assume(delegatee != address(0));
        vm.assume(permission == 0 || permission == 1);
        vm.assume(txDeadline > block.timestamp);

        erc721 = new ERC721BurnableMock("NFTMock", "MCK", delegator, 0);

        DelegatorAccount implementation = new DelegatorAccount();
        registry = new DelegatorRegistry(address(implementation));

        vm.startPrank(delegator);
        account = IDelegatorAccount(registry.registerDelegator());

        erc721.mint(delegator, tokenId);
        erc721.setApprovalForAll(address(account), true);

        assert(account.delegator() == delegator);

        IDelegatorAccount.NFTInfo memory nft = IDelegatorAccount.NFTInfo({
            tokenId: tokenId,
            nftContract: address(erc721)
        });
        delegatorsNfts.push(nft);
        account.delegateERC721(
            nft,
            delegatee,
            expiration,
            permission == 0 ? IDelegatorAccount.Permission.UNRESTRICTED : IDelegatorAccount.Permission.RESTRICTED,
            txDeadline
        );
    }

    function test_noDelegatorNFTloss(bytes4 selector) public virtual {
        (bytes memory args, address caller, uint256 msgValue) = mk_calldata(selector);
        deal(address(this), msgValue);

        vm.prank(caller);
        (bool success,) = address(account).call{value: msgValue}(args);
        vm.assume(success); // ignore reverting cases

        // Post call assertions
        assert(address(account).balance == 0);
        for (uint256 i; i < delegatorsNfts.length; i++) {
            assert(erc721.ownerOf(delegatorsNfts[i].tokenId) == address(delegator));
        }
    }

    function mk_calldata(bytes4 selector) internal view returns (bytes memory args, address caller, uint256 msgValue) {
        // Ignore view functions
        vm.assume(selector != IDelegatorAccount.delegator.selector &&
            selector != IDelegatorAccount.proposedCalldata.selector &&
            selector != IDelegatorAccount.getDelegateeInfo.selector &&
            selector != IDelegatorAccount.isRegisteredNFTContract.selector &&
            selector != IDelegatorAccount.onERC721Received.selector
        );

        // Create symbolic values to be included in calldata
        IDelegatorAccount.NFTInfo memory nft = IDelegatorAccount.NFTInfo({
            tokenId: tokenId,
            nftContract: address(erc721)
        });
        bool continueOnFailure = svm.createBool('continueOnFailure');
        bytes32 proposalHash = svm.createBytes32('proposalHash');
        uint256 proposalStatus = svm.createUint256('proposalStatus');
        vm.assume(proposalStatus >= 0 || proposalStatus < 5);

        // Halmos requires symbolic dynamic arrays to be given with a specific size.
        // In this test, we provide arrays with length 8.
        address[] memory targets = new address[](2);
        targets[0] = address(account);
        targets[1] = address(account);
        // targets[2] = svm.createAddress('target3');
        // targets[3] = svm.createAddress('target4');
        // targets[4] = svm.createAddress('target5');
        // targets[5] = svm.createAddress('target6');
        // targets[6] = svm.createAddress('target7');
        // targets[7] = svm.createAddress('target8');
        bytes[] memory data = new bytes[](8);
        data[0] = svm.createBytes(256, 'data1');
        data[1] = svm.createBytes(256, 'data2');
        // data[2] = svm.createBytes(256, 'data3');
        // data[3] = svm.createBytes(256, 'data4');
        // data[4] = svm.createBytes(256, 'data5');
        // data[5] = svm.createBytes(256, 'data6');
        // data[6] = svm.createBytes(256, 'data7');
        // data[7] = svm.createBytes(256, 'data8');
        uint256[] memory values = new uint256[](8);
        values[0] = svm.createUint256('value1');
        values[1] = svm.createUint256('value2');
        // values[2] = svm.createUint256('value3');
        // values[3] = svm.createUint256('value4');
        // values[4] = svm.createUint256('value5');
        // values[5] = svm.createUint256('value6');
        // values[6] = svm.createUint256('value7');
        // values[7] = svm.createUint256('value8');

        uint totalValue;
        for (uint i; i < 2; ++i) {
            totalValue += values[i];
        }
        
        // By default, caller is delegatee
        caller = delegatee;

        // Generate calldata based on the function selector
        if (selector == IDelegatorAccount.delegateERC721.selector) {
            caller = delegator;
            args = abi.encode(nft, delegatee, expiration, permission, txDeadline);
        } else if (selector == IDelegatorAccount.revokeERC721.selector) {
            caller = delegator;
            args = abi.encode(nft, delegatee);
        } else if (selector == IDelegatorAccount.multicall.selector) {
            args = abi.encode(targets, data, values, nft, continueOnFailure);
        } else if (selector == IDelegatorAccount.proposeCalldataExecution.selector) {
            args = abi.encode(targets, data, values, nft, continueOnFailure);
        } else if (selector == IDelegatorAccount.setProposalStatus.selector) {
            caller = delegator;
            args = abi.encode(proposalHash, proposalStatus);
        } else if (selector == IDelegatorAccount.executeProposal.selector) {
            args = abi.encode(targets, data, values, nft, continueOnFailure);
        } else {
            // For functions where all parameters are static (not dynamic arrays or bytes),
            // a raw byte array is sufficient instead of explicitly specifying each argument.
            args = svm.createBytes(1024, "data"); // chose a size that is large enough to cover all parameters
        }
        return (abi.encodePacked(selector, args), caller, totalValue);
    }
}