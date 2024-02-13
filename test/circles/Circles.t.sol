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

    // State variables

    MockCircles public circles;

    string[N] public avatars = ["alice", "bob", "charlie", "david"];
    address[N] public addresses;

    // Public functions

    function setUp() public {
        // set time to 15th October 2020
        _setUpTime(DEMURRAGE_DAY_ZERO + 1);

        _forwardTime(3 * 365 days + 100 days);

        circles = new MockCircles(DEMURRAGE_DAY_ZERO);

        for (uint256 i = 0; i < N; i++) {
            addresses[i] = makeAddr(avatars[i]);
            circles.registerHuman(addresses[i]);
        }
    }

    function testBlocktimestamp() public view {
        console.log("block.timestamp: %d", block.timestamp);
    }

    // Private function

    function _setUpTime(uint256 _time) internal {
        vm.warp(_time);
    }

    function _forwardTime(uint256 _duration) internal {
        vm.warp(block.timestamp + _duration);
    }
}
