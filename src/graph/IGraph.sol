// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./ICircleNode.sol";

interface IGraph {
    function avatarToCircle(address avatar) external view returns (IAvatarCircleNode);

    function checkAllAreTrustedCircleNodes(address group, ICircleNode[] calldata circles, bool includeGroups)
        external
        view
        returns (bool allTrusted);

    function migrateCircles(address owner, uint256 amount, IAvatarCircleNode circle) external returns (bool success);

    function fetchAllocation(address avatar) external returns (int128 allocation, uint256 earliestTimestamp);
}
