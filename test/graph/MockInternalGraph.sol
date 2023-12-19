// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/graph/Graph.sol";
import "../../src/graph/ICircleNode.sol";
import "../../src/migration/IHub.sol";
import "../../src/mint/IMintSplitter.sol";

contract MockInternalGraph is Graph {
    constructor(
        IMintSplitter _mintSplitter,
        IAvatarCircleNode _masterCopyAvatarCircleNode,
        IGroupCircleNode _masterCopyGroupCircleNode
    ) Graph(_mintSplitter, address(0), _masterCopyAvatarCircleNode, _masterCopyGroupCircleNode) {}

    function accessUnpackCoordinates(bytes calldata _packedData, uint256 _numberOfTriplets)
        public
        pure
        returns (uint16[] memory unpackedCoordinates_)
    {
        return super._unpackCoordinates(_packedData, _numberOfTriplets);
    }

    function notMocked() private pure {
        assert(false);
    }
}
