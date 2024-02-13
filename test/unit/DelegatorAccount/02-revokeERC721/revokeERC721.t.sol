// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest, IDelegatorAccount} from "../../BaseTest.t.sol";

contract RevokeERC721Test is BaseTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(DELEGATOR);
        erc721.setApprovalForAll(address(account), true);

        account.delegateERC721(
            erc721Info,
            DELEGATEE,
            oneDayExpiration,
            unrestricted,
            enoughDeadline
        );
    }

    function test_WhenMsgSenderIsNotTheDelegator() external {
        // it should revert with NotDelegator.

        vm.startPrank(RANDOM_USER);

        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegator.selector, RANDOM_USER)
        );

        account.revokeERC721(erc721Info, DELEGATEE);
    }

    function test_WhenAccountIsReenteredInSameTx() external {
        // it should revert with CallError because of a NotDelegator error.

        address[] memory targets = new address[](1);
        targets[0] = address(account);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            account.revokeERC721.selector,
            erc721Info,
            DELEGATEE
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes memory returnData = abi.encodeWithSelector(IDelegatorAccount.NotDelegator.selector, address(account));
        vm.expectRevert(abi.encodeWithSelector(IDelegatorAccount.CallError.selector, returnData, 0));
        
        vm.startPrank(DELEGATEE);
        account.multicall(targets, data, values, erc721Info, false);
    }

    function test_ShouldSetTheExpirationTimeForTheCallerAndDelegateeTo1()
        external
    {
        // it should set the expiration time for the caller and delegatee to 1.

        vm.startPrank(DELEGATOR);
        account.revokeERC721(erc721Info, DELEGATEE);
        
        (,uint256 callerExpiration) = account.getDelegateeInfo(
            DELEGATEE,
            erc721Info
        );

        assertEq(callerExpiration, 1);
    }

    function test_ShouldEmitAnERC721RevokedEvent() external {
        // it should emit an ERC721Revoked event.

        vm.startPrank(DELEGATOR);

        vm.expectEmit(true, true, false, true, address(account));

        emit ERC721Revoked(DELEGATEE, erc721Info);

        account.revokeERC721(erc721Info, DELEGATEE);
    }
}
