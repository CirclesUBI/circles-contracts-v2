// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IGraphNode {
    function trusts(IGraphNode _node) external view returns (bool);
}