// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest, IDelegatorAccount, IERC721} from "../../BaseTest.t.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract MulticallTest is BaseTest {
    uint256 DELEGATEE_TO_NFT_SLOT = 1;

    function setUp() public override {
        super.setUp();

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            oneDayExpiration,
            restricted,
            enoughDeadline
        );
    }

    // notes on how a malicious actor could try to reenter the multicall function for any reason
    // 1. If multicall calls itself, since address(account) isn't registered as delegatee, it will revert with NotDelegated.
    // 2. If mulitcall callsback delegatee, which then callsback multicall, it will revert with ERC721IncorrectOwner since the token is in account
    // 3. Multicall transfers NFT to delegatee, which onERC721received performs multiple operations in his own context for example approving himself
    // to spend the NFT to any account of him, so when he transfers back the NFT to account and the tx finalizes, the delegatee can transfer the NFT to any account of his own
    // But to do such a think he'd need UNRESTRICTED permissions, since with RESTRICTED permissions he can't transfer the NFT to any account of his own since he can't interact with any NFT contract registered by the delegator
    // Note: see my post-second-iteration.md thoughts on Permissions, specifically how PARTIAL could potentially be used to limit this attack vector
    function test_WhenMulticallCallsItself() external {
        // it should revert with NotDelegated.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory data = new bytes[](1);
        // expected to have already failed, calldata
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.onERC721Received.selector,
            address(0),
            address(0),
            0,
            "",
            false
        );
        // reentrantCallData
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.multicall.selector,
            targets,
            data,
            values,
            erc721Info,
            false
        );

        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.multicall.selector,
            targets,
            data,
            values,
            erc721Info,
            false
        );

        vm.startPrank(DELEGATEE);
        bytes memory returnData = abi.encodeWithSelector(IDelegatorAccount.NotDelegated.selector, address(account));
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.CallError.selector, returnData, 0)
        );

        account.multicall(targets, data, values, erc721Info, false);
    }

    function test_WhenMsgSenderIsNotADelegateERC721() external {
        // it should revert with NotDelegated.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.delegateERC721.selector,
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        vm.startPrank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegated.selector, RANDOM_USER)
        );
        account.multicall(targets, data, values, erc721Info, false);
    }

    function test_WhenNFTIsNotRegistered() external {
        // it should revert with NotDelegated.

        erc721Info.tokenId = 0;

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.delegateERC721.selector,
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        vm.startPrank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegated.selector, address(DELEGATEE))
        );
        account.multicall(targets, data, values, erc721Info, false);
    }

    function test_WhenExpirationTimeIsLtCurrentTime() external {
        // it should revert with NotDelegated.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.onERC721Received.selector,
            address(0),
            address(0),
            0,
            ""
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        // since the expiration time is set in test setup, we'll have to low level change it, but since I'm in a fork, I can't change the storage of the contract
        /*
        bytes32 hash = keccak256(abi.encode(erc721Info));
        bytes32 expirationSlot = bytes32(
            uint256(keccak256(abi.encode(hash, keccak256(abi.encode(DELEGATEE, DELEGATEE_TO_NFT_SLOT)))))
        );
        vm.store(address(account), expirationSlot, bytes32(oneDayExpiration));
        vm.rollFork(type(uint48).max);
        */
        // I'll change it in a less hacky way
        vm.prank(DELEGATOR);
        account.revokeERC721(erc721Info, DELEGATEE);

        vm.startPrank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegated.selector, DELEGATEE)
        );
        account.multicall(targets, data, values, erc721Info, false);
    }

    function test_WhenTheTokenIsNotApprovedForTheDelegate() external {
        // it should revert with ERC721InsufficientApproval.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.delegateERC721.selector,
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), false);

        vm.prank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, address(account), erc721Info.tokenId)
        );
        account.multicall(targets, data, values, erc721Info, false);

    }

    modifier givenTheTokenIsApprovedForTheDelegate() {
        _;
    }

    function test_GivenTheTokenIsApprovedForTheDelegate() external givenTheTokenIsApprovedForTheDelegate {
        // it should call the target contract with the given data and value with no reverts.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.onERC721Received.selector,
            address(0),
            address(0),
            0,
            ""
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        vm.startPrank(DELEGATEE);
        account.multicall(targets, data, values, erc721Info, false);
    }

    function test_GivenATargetAddressIsAnyRegisteredNFTContractAndPermissionsAreRESTRICTED()
        external
        givenTheTokenIsApprovedForTheDelegate
    {
        // it should revert with PermissionViolation.

        address[] memory targets = new address[](1);
        targets[0] = address(erc721);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IERC721.transferFrom.selector,
            address(account),
            DELEGATEE,
            erc721Info.tokenId
        );

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        vm.startPrank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.PermissionViolation.selector, DELEGATEE, IDelegatorAccount.Permission.RESTRICTED)
        );
        account.multicall(targets, data, values, erc721Info, false);
    }

    modifier givenTheCallReverts() {
        _;
    }

    function test_GivenContinueOnFailureIsFalse() external givenTheTokenIsApprovedForTheDelegate givenTheCallReverts {
        // it should revert with CallError.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            ""
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        vm.startPrank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.CallError.selector, "", 0)
        );
        account.multicall(targets, data, values, erc721Info, false);
    }

    function test_GivenContinueOnFailureIsTrue() external givenTheTokenIsApprovedForTheDelegate givenTheCallReverts {
        // it should not revert.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        // this calldata will revert, and make the low level call return false on success
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.delegateERC721.selector,
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        vm.startPrank(DELEGATEE);
        account.multicall(targets, data, values, erc721Info, true);
    }

    modifier givenTheCallDoesntRevert() {
        _;
    }

    function test_GivenTheCallDoesntRevert() external givenTheTokenIsApprovedForTheDelegate givenTheCallDoesntRevert {
        // it should transfer back the NFT.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.revokeERC721.selector,
            erc721Info,
            DELEGATEE
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        vm.startPrank(DELEGATEE);
        account.multicall(targets, data, values, erc721Info, true);

        assertEq(erc721.ownerOf(erc721Info.tokenId), DELEGATOR);
    }

    modifier givenTheAccountKeepsETH() {
        _;
    }

    // sends 1 ether thourgh a contract that will revert on receive
    // the value param is set to 0, so the ether will be stuck in the contract
    // testing if the multicall reverts correctly if ether callback fails
    function test_GivenTheETHTransferFails()
        external
        givenTheTokenIsApprovedForTheDelegate
        givenTheCallDoesntRevert
        givenTheAccountKeepsETH
    {
        // it should revert with CallError.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.onERC721Received.selector,
            address(0),
            address(0),
            0,
            ""
        );
        bytes memory accountCalldata = abi.encode(
            targets,
            data,
            values,
            erc721Info,
            true
        );

        // give the delegatee some ETH
        deal(DELEGATEE, 1 ether);

        vm.prank(DELEGATOR);
        account.delegateERC721(
            erc721Info,
            address(ethTransferFail),
            noExpiration,
            unrestricted,
            enoughDeadline
        );

        vm.startPrank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.CallError.selector, "Failed to send ether", 1)
        );
        ethTransferFail.execute{value: 1 ether}(address(account), accountCalldata);

        assertEq(address(account).balance, 0);
        assertEq(address(DELEGATEE).balance, 1 ether);
    }

    // sets only 1 ether as value, but sends 2 ether
    // on top of that the target contract will revert but pass due to the continueOnFailure flag being set to true
    function test_GivenTheETHTransferSucceeds()
        external
        givenTheTokenIsApprovedForTheDelegate
        givenTheCallDoesntRevert
        givenTheAccountKeepsETH
    {
        // it should transfer the ETH back to the delegatee.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            IDelegatorAccount.onERC721Received.selector,
            address(0),
            address(0),
            0,
            ""
        );

        // give the delegatee some ETH
        deal(DELEGATEE, 2 ether);

        vm.startPrank(DELEGATEE);
        account.multicall{value: 1 ether}(targets, data, values, erc721Info, true);
        assertEq(address(account).balance, 0);
        assertEq(address(DELEGATEE).balance, 2 ether);
    }
}
