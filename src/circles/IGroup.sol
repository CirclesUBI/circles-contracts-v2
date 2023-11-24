// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../graph/ICircleNode.sol";

interface IGroup {
    // todo: these are sketches of a simple interface
    // should be considered again
    function beforeMintPolicy(address minter, ICircleNode[] calldata collateral, uint256[] calldata amount) external;
}
