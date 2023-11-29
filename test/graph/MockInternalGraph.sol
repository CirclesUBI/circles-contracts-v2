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
    ) Graph(_mintSplitter, _masterCopyAvatarCircleNode, _masterCopyGroupCircleNode) {}

    // function trust(address _avatar) external override {
    //     notMocked();
    // }

    // function untrust(address _avatar) external override {
    //     notMocked();
    // }

    // function checkAncestorMigrations(address _avatar)
    //     public view override
    //     returns (bool objectToStartMint_, address[] memory migrationTokens_) {
    //         notMocked();
    //         address[] memory nothing = new address[](0);
    //         return (false, nothing);
    //     }

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
