// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest, IDelegatorAccount} from "../../BaseTest.t.sol";
import {console} from "forge-std/console.sol";

contract DelegateERC721Test is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenMsgSenderIsNotTheDelegator() external {
        // it should revert with NotDelegator.

        vm.startPrank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegator.selector, RANDOM_USER)
        );
        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            oneDayExpiration,
            unrestricted,
            enoughDeadline
        );
    }

    function test_WhenTheExecutingDeadlineIsPassed() external {
        // it should revert with ExpiredDeadline.

        vm.startPrank(DELEGATOR);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.ExpiredDeadline.selector, expiredDeadline)
        );
        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            expiredDeadline
        );
    }

    function test_WhenTheTokenIsNotApprovedForTheDelegatee() external {
        // it should revert with NotApproved.

        vm.startPrank(DELEGATOR);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotApprovedForAll.selector, erc721Info.nftContract)
        );
        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );
    }

    function test_WhenAccountIsReenteredInSameTx() external {
        // it should revert with NotDelegator.

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );

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

        bytes memory returnData = abi.encodeWithSelector(IDelegatorAccount.NotDelegator.selector, address(account));
        vm.expectRevert(abi.encodeWithSelector(IDelegatorAccount.CallError.selector, returnData, 0));

        vm.startPrank(DELEGATEE);
        account.multicall(targets, data, values, erc721Info, false);
    }

    modifier givenTheTokenIsApprovedForTheDelegate() {
        _;
    }

    function test_GivenTheTokenIsApprovedForTheDelegate()
        external
        givenTheTokenIsApprovedForTheDelegate
    {
        // it should store the delegatee permissions.

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );

        (IDelegatorAccount.Permission permission,) = account.getDelegateeInfo(DELEGATEE, erc721Info);

        assertEq(uint256(permission), uint256(unrestricted));
    }

    function test_GivenExpirationTimeIsGteCurrentTime()
        external
        givenTheTokenIsApprovedForTheDelegate
    {
        // it should store the expiration time for the caller and delegatee.

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            oneDayExpiration,
            unrestricted,
            enoughDeadline
        );

        (,uint256 expiration) = account.getDelegateeInfo(DELEGATEE, erc721Info);

        assertEq(expiration, oneDayExpiration);
    }

    function test_GivenExpirationTimeIsLtCurrentTime()
        external
        givenTheTokenIsApprovedForTheDelegate
    {
        // it should store max uint256 value, signaling there is no expiration.

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );

        (,uint256 expiration) = account.getDelegateeInfo(DELEGATEE, erc721Info);
        
        assertEq(expiration, type(uint256).max);
    }

    function test_GivenNftContractIsNotYetRegistered()
        external
        givenTheTokenIsApprovedForTheDelegate
    {
        // it should register the nftContract.

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );

        bool isRegistered = account.isRegisteredNFTContract(erc721Info.nftContract);
        assertTrue(isRegistered);
    }

    function test_GivenTheNftDelegationHadAlreadyBeenDone()
        external
        givenTheTokenIsApprovedForTheDelegate
    {
        // it should emit the ChangedDelegateeConfig event.

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );

        vm.expectEmit(true, true, false, true, address(account));

        emit ChangedDelegateeConfig(
            DELEGATEE,
            erc721Info,
            noExpiration,
            unrestricted
        );

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );
    }

    function test_GivenTheNftDelegationHasNotBeenDone()
        external
        givenTheTokenIsApprovedForTheDelegate
    {
        // it should emit the NewERC721Delegated event.

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        vm.expectEmit(true, true, false, false, address(account));

        emit NewERC721Delegated(DELEGATEE, erc721Info, noExpiration);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            noExpiration,
            unrestricted,
            enoughDeadline
        );
    }
}
