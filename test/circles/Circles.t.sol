// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "./MockCircles.sol";
import "../setup/TimeSetup.sol";

contract CirclesTest is Test, TimeSetup {
    // Constants

    uint256 public constant N = 4;

    uint256 public constant DAY0 = (3 * 365 days + 100 days) / 1 days;

    // State variables

    MockCircles public circles;

    string[N] public avatars = ["alice", "bob", "charlie", "david"];
    address[N] public addresses;

    // Public functions

    function setUp() public {
        // set time to 15th October 2020
        _setUpTime(DEMURRAGE_DAY_ZERO + 1);

        // 23 january 2024 12:01 am UTC
        _forwardTime(DAY0 * 1 days);

        circles = new MockCircles(DEMURRAGE_DAY_ZERO);

        for (uint256 i = 0; i < N; i++) {
            addresses[i] = makeAddr(avatars[i]);
            circles.registerHuman(addresses[i]);
        }
    }

    function testCalculateIssuance() public {
        circles.updateTodaysInflationFactor();
        uint256 day = circles.day(block.timestamp);
        assertEq(day, DAY0);
        uint256 issuance = circles.calculateIssuance(addresses[0]);
        assertEq(issuance, 0);

        _forwardTime(30 minutes);
        // still the same day
        assertEq(circles.day(block.timestamp), DAY0);
        issuance = circles.calculateIssuance(addresses[0]);
        assertEq(issuance, 0);

        _forwardTime(31 minutes);
        issuance = circles.calculateIssuance(addresses[0]);
        assertEq(issuance, 999999999999999979);
    }

    // Private functions

    function _setUpTime(uint256 _time) internal {
        vm.warp(_time);
    }

    function _forwardTime(uint256 _duration) internal {
        vm.warp(block.timestamp + _duration);
    }
}
