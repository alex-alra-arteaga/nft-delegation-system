// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface IDelegatorRegistry {
    event DelegatorRegistered(address indexed delegator, address indexed account);

    function registerDelegator() external returns (address account);
}