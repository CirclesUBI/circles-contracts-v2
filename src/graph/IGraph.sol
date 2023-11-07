// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./ICircleNode.sol";

interface IGraph {
    function trust(address _avatar) external;
    function untrust(address _avatar) external;

    function checkAncestorMigrations(address _avatar)
        external
        returns (bool objectToStartMint_, address[] memory migrationTokens_);
}
