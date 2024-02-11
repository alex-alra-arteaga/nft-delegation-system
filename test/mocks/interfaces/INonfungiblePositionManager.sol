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

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external;

    function setApprovalForAll(address operator, bool approved) external;
}