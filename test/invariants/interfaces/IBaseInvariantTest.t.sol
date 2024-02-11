// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface IBaseInvariantTest {
    function currentTimestamp() external view returns (uint256);

    function setCurrentTimestamp(uint256 currentTimestamp) external;
}
