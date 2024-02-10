// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IDelegatorRegistry} from "./interfaces/IDelegatorRegistry.sol";
import {IDelegatorAccount} from "./interfaces/IDelegatorAccount.sol";

/**
 * @title DelegatorRegistry
 * @author Alex Arteaga, future Openfort Blockchain Engineer
 * @notice This contract is intended to be used as a registry for multi assets delegations
 */
contract DelegatorRegistry is IDelegatorRegistry {
    using Clones for address;

    address public implementation;
    mapping(address delegator => address account) public delegatorToAccount;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function registerDelegator() public returns (address account) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender));

        account = implementation.cloneDeterministic(salt);

        IDelegatorAccount(account).initialize(msg.sender);

        delegatorToAccount[msg.sender] = account;

        emit DelegatorRegistered(msg.sender, account);
    }

    function predictAccountAddress(address delegator) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(delegator));

        return implementation.predictDeterministicAddress(salt);
    }
}
