// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseInvariant} from './BaseInvariant.t.sol';
import {AddressSet, LibAddressSet} from "./helpers/AddressSet.sol";
import {IDelegatorAccount} from "../../src/interfaces/IDelegatorAccount.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DelegatorAccountInvariants is BaseInvariant {
    using LibAddressSet for AddressSet;

    /// @dev All invariants related to DelegatorAccount.sol contract are here
    function invariant_delegatorShouldNotLoseAnyERC721() public useCurrentTimestamp {
        // need array of nfts to check ownership

        for (uint256 i; i < accountHandler.delegatorsNFTsLength(); i++) {
            assertDelegatorOwnership(i);
        }
    }

    function invariant_delegatorAccountShouldnotStoreEth() public useCurrentTimestamp {
        assertEq(address(accountHandler.account()).balance, 0);
    }

    function invariant_mutationFunctionsCanOnlyBeCalledByDelegatorsOrDelegatees() public useCurrentTimestamp {
        // call mutation functions with different actors and check if they revert

        accountHandler.forEachActor(this.assertMutationAccessGuards);
    }

    /// @dev Is useful to test if the state variables are corrupted at some point
    function invariant_gettersShouldNotRevert() public useCurrentTimestamp {
        // call all getters and check if they revert
        IDelegatorAccount.NFTInfo memory nftInfo = IDelegatorAccount.NFTInfo({
            nftContract: address(0),
            tokenId: 0
        });

        accountHandler.account().getDelegateeInfo(address(0), nftInfo);
        accountHandler.account().getDelegateeInfo(address(0), nftInfo);
    }

    function invariant_callSummary() public view {
        accountHandler.callSummary();
    }

    // Helper Assertions

    function assertDelegatorOwnership(uint256 index) internal {
        IERC721 nftContract = IERC721(accountHandler.getDelegatorsNFTs(index).nftContract);
        assertEq(nftContract.ownerOf(accountHandler.getDelegatorsNFTs(index).tokenId), address(accountHandler.account().delegator()));
    }

    function assertMutationAccessGuards(address randUser) public {
        assertEq(accountHandler.hasActorSuccededInProhibitedAction(randUser), false);
    }
}