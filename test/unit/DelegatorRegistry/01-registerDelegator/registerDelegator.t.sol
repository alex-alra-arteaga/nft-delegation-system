// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {BaseTest} from "../../BaseTest.t.sol";

contract RegisterDelegatorTest is BaseTest {

    function setUp() public override {
        super.setUp();
    }
    
    function test_WhenMsgSenderAlreadyHasAnAccount() external {
        // it reverts with ERC1167FailedCreateClone.
    }

    function test_DeploysAnInstanceOfImplementation() external {
        // it deploys an instance of implementation.
    }

    function test_EmitsADelegatorCreatedEvent() external {
        // it emits a DelegatorCreated event.
    }
}
