// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/hub/Hub.sol";
import "../../src/migration/IHub.sol";

abstract contract MockV1Hub is IHubV1 {}

contract MockMigrationHub is Hub {
    // Constructor

    constructor(uint256 _inflationDayZero, uint256 _bootstrapTime)
        Hub(
            IHubV1(address(1)),
            INameRegistry(address(0)),
            address(0),
            IERC20Lift(address(0)),
            address(1),
            _inflationDayZero,
            _bootstrapTime,
            ""
        )
    {}
}
