// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest, IDelegatorAccount, INonfungiblePositionManager} from "../../BaseTest.t.sol";

contract SetProposalStatusTest is BaseTest {
    bytes32 incorrectProposalHash;

    function setUp() public override {
        super.setUp();

        vm.startPrank(DELEGATEE);
        lpAccount.proposeCalldataExecution(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );
    }

    function test_WhenMsgSenderIsNotDelegator() external {
        // it should revert with NotDelegator.

        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegator.selector, RANDOM_USER)
        );
        vm.startPrank(RANDOM_USER);
        lpAccount.setProposalStatus(0, IDelegatorAccount.ProposalStatus.APPROVED);
    }

    function test_WhenTheProposalIsNotFound() external {
        // it should revert with InvalidProposalStatus.

        incorrectProposalHash = keccak256(
            abi.encode(
                DELEGATEE,
                lpTargets,
                lpData,
                lpValue,
                lpNFTInfo,
                true
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.InvalidProposalStatus.selector, IDelegatorAccount.ProposalStatus.UNINITIALIZED, IDelegatorAccount.ProposalStatus.APPROVED)
        );
        vm.startPrank(LP_DELEGATOR);
        lpAccount.setProposalStatus(incorrectProposalHash, IDelegatorAccount.ProposalStatus.APPROVED);
    }

    function test_WhenTheNewProposalStatusIsNeitherExecutedNorRejected() external {
        // it should revert with InvalidProposalStatus.
        
        vm.startPrank(LP_DELEGATOR);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.InvalidProposalStatus.selector, IDelegatorAccount.ProposalStatus.PENDING, IDelegatorAccount.ProposalStatus.PENDING)
        );
        lpAccount.setProposalStatus(proposalHash, IDelegatorAccount.ProposalStatus.PENDING);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.InvalidProposalStatus.selector, IDelegatorAccount.ProposalStatus.PENDING, IDelegatorAccount.ProposalStatus.UNINITIALIZED)
        );
        lpAccount.setProposalStatus(proposalHash, IDelegatorAccount.ProposalStatus.UNINITIALIZED);

    }

    function test_ShouldSetProposalStatus() external {
        // it should set proposal status.

        vm.startPrank(LP_DELEGATOR);
        lpAccount.setProposalStatus(proposalHash, IDelegatorAccount.ProposalStatus.APPROVED);

        IDelegatorAccount.ProposalStatus status = lpAccount.proposedCalldata(proposalHash);

        assertTrue(status == IDelegatorAccount.ProposalStatus.APPROVED);
    }

    function test_ShouldEmitProposalStatusChangedEvent() external {
        // it should emit ProposalStatusChanged event.

        vm.expectEmit(true, true, false, true, address(lpAccount));

        emit ProposalStatusChanged(proposalHash, IDelegatorAccount.ProposalStatus.APPROVED);
        
        vm.startPrank(LP_DELEGATOR);
        lpAccount.setProposalStatus(proposalHash, IDelegatorAccount.ProposalStatus.APPROVED);
    }
}
