// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../../src/migration/Migration.sol";
import "./MockHub.sol";

contract MigrationTest is Test {
    // Constants

    uint256 private ACCURACY_ONE = uint256(10 ** 8);
    uint256 private ACCURACY_ONE_HUNDREDTH = uint256(10 ** 6);
    // 6:00:18 pm UTC  |  Monday, December 11, 2023
    uint256 private MOMENT_IN_TIME = uint256(1702317618);

    // State variables

    MockHubV1 public mockHubV1;

    Migration public migration;

    // Setup

    function setUp() public {
        mockHubV1 = new MockHubV1();

        migration = new Migration(mockHubV1, IHubV2(address(1)));

        vm.warp(MOMENT_IN_TIME);
    }

    // Tests

    function testConversionMigrationV1ToTimeCircles() public {
        // `MOMENT_IN_TIME` is in the third period
        assertEq(uint256(3), mockHubV1.periods());

        uint256 originalAmountV1 = uint256(7471193061687490000000);
        // at the constant `MOMENT_IN_TIME`
        uint256 expectedAmountV2 = uint256(1809845 * 10 ** 16);

        // this is a crude first test. These tests should be redone more accurately
        // possibly even on-chain

        // for now require accuracy < 1%
        uint256 convertedAmount = migration.convertFromV1ToDemurrage(originalAmountV1);
        uint256 difference = uint256(0);
        if (convertedAmount < expectedAmountV2) {
            difference = ACCURACY_ONE - (ACCURACY_ONE * convertedAmount) / expectedAmountV2;
        } else {
            difference = ACCURACY_ONE - (ACCURACY_ONE * expectedAmountV2) / convertedAmount;
        }
        uint256 relativeDifference = difference / ACCURACY_ONE_HUNDREDTH;
        assertEq(0, relativeDifference);
    }
}
