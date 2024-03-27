// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/names/INameRegistry.sol";
import "../../src/hub/Hub.sol";
import "../migration/MockHub.sol";

contract MockMigrationHub is Hub {
    // Constructor

    constructor(IHubV1 _hubV1, address _migration, uint256 _inflationDayZero, uint256 _bootstrapTime)
        Hub(
            _hubV1,
            INameRegistry(address(0)),
            _migration,
            IERC20Lift(address(0)),
            address(1),
            _inflationDayZero,
            _bootstrapTime,
            ""
        )
    {}

    // External functions

    function setSiblings(address _migration, address _nameRegistry) external {
        migration = _migration;
        nameRegistry = INameRegistry(_nameRegistry);
    }
}
