// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest, IDelegatorRegistry, IDelegatorAccount} from "../../BaseTest.t.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract RegisterDelegatorTest is BaseTest {

    function setUp() public override {
        super.setUp();
        // setUp already deploys the DelegatorRegistry contract for DELEGATOR.
    }
    
    function test_WhenMsgSenderAlreadyHasAnAccount() external {
        // it reverts with ERC1167FailedCreateClone.

        vm.expectRevert(
            abi.encodeWithSelector(Clones.ERC1167FailedCreateClone.selector)
        );
        vm.startPrank(DELEGATOR);
        registry.registerDelegator();
    }

    function test_DeploysAnInstanceOfImplementation() external {
        // it deploys an instance of implementation.

        address expectedAccountAddress = registry.predictAccountAddress(DELEGATOR);

        assertEq(address(account), expectedAccountAddress);
        assertEq(IDelegatorAccount(account).delegator(), DELEGATOR);
    }

    function test_EmitsADelegatorCreatedEvent() external {
        // it emits a DelegatorCreated event.

        address expectedAccountAddress = registry.predictAccountAddress(ERC721A_DELEGATOR);

        vm.expectEmit(true, true, false, true, address(registry));

        emit DelegatorRegistered(ERC721A_DELEGATOR, expectedAccountAddress);

        vm.startPrank(ERC721A_DELEGATOR);
        registry.registerDelegator();
    }
}
