// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {Test} from 'forge-std/Test.sol';
import {TimeWarper} from "./helpers/TimeWarper.sol";
import {IBaseInvariantTest} from "./interfaces/IBaseInvariantTest.t.sol";
import {AccountHandler} from "./handlers/AccountHandler.t.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

abstract contract BaseInvariant is Test, IBaseInvariantTest {
    AccountHandler internal accountHandler;
    TimeWarper internal s_timeWarper;
    uint256 internal s_currentTimestamp;
    address internal DELEGATOR = makeAddr("DELEGATOR");

    /// @dev Override BaseTest::setUp
    function setUp() public {
        /// @dev Set time management
        s_currentTimestamp = block.timestamp;

        s_timeWarper = new TimeWarper(IBaseInvariantTest(this));

        bytes4[] memory timeWarperSelectors = new bytes4[](1);
        timeWarperSelectors[0] = TimeWarper.warp.selector;
        // set TimeWarper as a handler
        targetSelector(
            StdInvariant.FuzzSelector({
                addr: address(s_timeWarper),
                selectors: timeWarperSelectors
            })
        );
        targetContract(address(s_timeWarper));

        /// @dev Set Handlers with their selectors
        accountHandler = new AccountHandler(IBaseInvariantTest(this));

        bytes4[] memory accountHandlerSelectors = new bytes4[](6);
        accountHandlerSelectors[0] = AccountHandler.delegateERC721.selector;
        accountHandlerSelectors[1] = AccountHandler.revokeERC721.selector;
        accountHandlerSelectors[2] = AccountHandler.multicall.selector;
        accountHandlerSelectors[3] = AccountHandler.proposeCalldataExecution.selector;
        accountHandlerSelectors[4] = AccountHandler.setProposalStatus.selector;
        accountHandlerSelectors[5] = AccountHandler.executeProposal.selector;

        targetSelector(
            StdInvariant.FuzzSelector({
                addr: address(accountHandler),
                selectors: accountHandlerSelectors
            })
        );
        targetContract(address(accountHandler));

        /// @dev exclude sender from sending transactions to the handlers
        _excludeSenderDeployedContracts();
        
        vm.stopPrank();
    }

    function _excludeSenderDeployedContracts() private {
        excludeSender(address(s_timeWarper));
        excludeSender(address(accountHandler));
    }

    /// @notice Returns the current stored timestamp, set during the last invariant test run
    /// @return The current stored timestamp
    function currentTimestamp() external view returns (uint256) {
        return s_currentTimestamp;
    }

    function setCurrentTimestamp(uint256 time) external {
        s_currentTimestamp = time;
    }

    /// @notice Sets the block timestamp to the current stored timestamp
    /// @dev Invariant tests should use this modifier to use the correct timestamp.
    /// See this issue for more info: https://github.com/foundry-rs/foundry/issues/4994.
    modifier useCurrentTimestamp() {
        vm.warp(s_currentTimestamp);
        _;
    }

    function getRandomActor() public view returns (address) {
        address[] memory actors = accountHandler.getActors();
        return actors[_getRandomNumber(0, actors.length - 1)];
    }

    /// @notice Returns a random number between min and max (both inclusive)
    /// @param min The minimum number
    /// @param max The maximum number
    /// @return A random number between min and max
    function _getRandomNumber(
        uint256 min,
        uint256 max
    ) internal view returns (uint256) {
        return min + (uint256(keccak256(abi.encode(block.timestamp))) % (max - min + 1));
    }
}
