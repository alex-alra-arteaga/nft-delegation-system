// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest, IDelegatorAccount, INonfungiblePositionManager, IERC20} from "../../BaseTest.t.sol";

contract ExecuteProposalTest is BaseTest {
    function setUp() public override {
        super.setUp();

        vm.prank(DELEGATEE);
        lpAccount.proposeCalldataExecution(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );
    }

    function test_WhenProposedCalldataIsNotApproved() external {
        // it should revert with NotDelegated.

        vm.prank(LP_DELEGATOR);
        lpAccount.setProposalStatus(proposalHash, IDelegatorAccount.ProposalStatus.REJECTED);

        // Rejected proposal
        vm.startPrank(DELEGATEE);
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegated.selector, DELEGATEE)
        );
        lpAccount.executeProposal(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );
        // Uninitialized proposal
        vm.expectRevert(
            abi.encodeWithSelector(IDelegatorAccount.NotDelegated.selector, DELEGATEE)
        );
        lpAccount.executeProposal(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            true
        );
    }

    /// @notice Example of how Delegatee can claim LP fees using Delegators LP NFTs
    function test_GivenTheProposedCalldataMatchesWithTheApprovedCalldata() external {
        // it should set the proposal state to Executed.
        // it should execute the proposed calldata.

        vm.prank(LP_DELEGATOR);
        lpAccount.setProposalStatus(proposalHash, IDelegatorAccount.ProposalStatus.APPROVED);

        vm.prank(DELEGATEE);
        lpAccount.executeProposal(
            lpTargets,
            lpData,
            lpValue,
            lpNFTInfo,
            false
        );

        IDelegatorAccount.ProposalStatus status = lpAccount.proposedCalldata(proposalHash);

        assertTrue(status == IDelegatorAccount.ProposalStatus.EXECUTED); 
        assertTrue(tBTC.balanceOf(LP_DELEGATOR) == AMOUNT0);
        assertTrue(wBTC.balanceOf(LP_DELEGATOR) == AMOUNT1);
    }
}
