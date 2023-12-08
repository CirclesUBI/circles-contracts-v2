// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./ICircleNode.sol";

interface IGraph {
    function checkAllAreTrustedCircleNodes(address group, ICircleNode[] calldata circles, bool includeGroups)
        external
        view
        returns (bool allTrusted_);

    function fetchAllocation(address _avatar) external returns (int128 allocation_, uint256 earliestTimestamp_);
}
