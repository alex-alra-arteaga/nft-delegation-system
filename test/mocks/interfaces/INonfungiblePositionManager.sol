// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface INonfungiblePositionManager {
    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        uint256 _deadline
    ) external;

    function collect(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _deadline
    ) external;
}