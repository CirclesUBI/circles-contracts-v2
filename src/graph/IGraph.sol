// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./ICircleNode.sol";

interface IGraph {
    function spendGlobalAllowance(address entity, address spender, uint256 amount) external;
    function globalAllowances(address entity, address spender) external view returns (uint256);
    function globalAllowanceTimestamps(address entity, address spender) external view returns (uint256 timestamp);

    function avatarToCircle(address avatar) external view returns (IAvatarCircleNode);

    function checkAllAreTrustedCircleNodes(address group, ICircleNode[] calldata circles, bool includeGroups)
        external
        view
        returns (bool allTrusted);

    function migrateCircles(address owner, uint256 amount, IAvatarCircleNode circle)
        external
        returns (uint256 migratedAmount);

    function fetchAllocation(address avatar) external returns (int128 allocation, uint256 earliestTimestamp);
}
