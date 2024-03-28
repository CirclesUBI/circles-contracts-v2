// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/hub/Hub.sol";
import "../../src/names/NameRegistry.sol";

contract MockNameRegistry is NameRegistry {
    // Constructor

    constructor(IHubV2 _hubV2) NameRegistry(_hubV2) {}

    // External functions

    function setHubV2(IHubV2 _hubV2) external {
        hub = _hubV2;
    }
}
