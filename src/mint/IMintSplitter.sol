// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IMintSplitter {
    function allocationTowardsCaller(address source) external returns (int128 allocation, uint256 earliestTimestamp);
}
