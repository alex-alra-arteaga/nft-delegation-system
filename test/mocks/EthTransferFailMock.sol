// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {IDelegatorAccount} from "../../src/interfaces/IDelegatorAccount.sol";

contract EthTransferFailMock {
    function execute(address account, bytes calldata _data) external payable {
        (address[] memory targets,
        bytes[] memory data,
        uint256[] memory value,
        IDelegatorAccount.NFTInfo memory info,
        bool continueOnFailure) = abi.decode(_data, (address[], bytes[], uint256[], IDelegatorAccount.NFTInfo, bool));
        
        IDelegatorAccount(account).multicall{value: msg.value}(targets, data, value, info, continueOnFailure);
    }
    receive() external payable {
        revert("EthTransferFailMock: receive() failed");
    }

    fallback() external payable {}
}