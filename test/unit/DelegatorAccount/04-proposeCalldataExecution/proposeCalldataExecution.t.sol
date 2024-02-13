// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest, IDelegatorAccount, INonfungiblePositionManager} from "../../BaseTest.t.sol";

contract ProposeCalldataExecutionTest is BaseTest {

    function setUp() public override {
        super.setUp();
    }

    function test_WhenMsgSenderIsNotDelegatee() external {
        // it should revert with NotDelegated.

        vm.startPrank(RANDOM_USER);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegated.selector, RANDOM_USER)
        );

        lpAccount.proposeCalldataExecution(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );
    }

    function test_WhenMsgSenderPermissionIsUNRESTRICTED() external {
        // it should revert with NotDelegateeWithRestrictedPermission.

        vm.startPrank(LP_DELEGATOR);
        lpAccount.delegateERC721(
            lpNFTInfo,
            DELEGATEE,
            oneDayExpiration,
            unrestricted,
            enoughDeadline
        );

        vm.startPrank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegateeWithRestrictedPermission.selector, DELEGATEE)
        );
        
        lpAccount.proposeCalldataExecution(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );
    }

    function test_ShouldStoreTheProposalStatusAsPending() external {
        // it should store the proposal status as Pending.

        vm.startPrank(DELEGATEE);
        lpAccount.proposeCalldataExecution(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );

        IDelegatorAccount.ProposalStatus status = lpAccount.proposedCalldata(proposalHash);

        assertTrue(status == IDelegatorAccount.ProposalStatus.PENDING);
    }

    function test_ShouldEmitAProposalCreatedEvent() external {
        // it should emit a ProposalCreated event.


        vm.expectEmit(true, true, false, true, address(lpAccount));

        emit CalldataProposed(
            proposalHash,
            DELEGATEE,
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );

        vm.startPrank(DELEGATEE);
        lpAccount.proposeCalldataExecution(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );
    }
}
