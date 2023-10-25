// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./ITimeNode.sol";

interface IGraph {

    function trust(IGraphNode _node) external;
    function untrust(IGraphNode _node) external;

    function isTrusted(IGraphNode _centerNode, IGraphNode _circleNode)
        external
        view
        returns (bool);

}

