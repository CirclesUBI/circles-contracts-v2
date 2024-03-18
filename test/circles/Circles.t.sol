// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "./MockCircles.sol";
import "../setup/TimeSetup.sol";
import "../utils/Approximation.sol";

contract CirclesTest is Test, TimeSetup, Approximation {
    // Constants

    uint256 public constant N = 4;

    uint256 public constant DAY0 = (3 * 365 days + 100 days) / 1 days;

    uint256 public constant EPS = 10 ** (18 - 2);

    uint256 public constant CRC = 10 ** 18;

    // State variables

    MockCircles public circles;

    string[N] public avatars = ["alice", "bob", "charlie", "david"];
    address[N] public addresses;
    uint256[N] public circlesIdentifiers;

    // Public functions

    function setUp() public {
        // set time to 15th October 2020
        _setUpTime(INFLATION_DAY_ZERO + 1);

        // 23 january 2024 12:01 am UTC
        _forwardTime(DAY0 * 1 days);

        circles = new MockCircles(INFLATION_DAY_ZERO);

        for (uint256 i = 0; i < N; i++) {
            addresses[i] = makeAddr(avatars[i]);
            circlesIdentifiers[i] = circles.toTokenId(addresses[i]);
            circles.registerHuman(addresses[i]);
        }
    }

    function testCalculateIssuance() public {
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
        assertEq(issuance, 1 * CRC);

        _forwardTime(1 days + 2 hours + 15 minutes);
        issuance = circles.calculateIssuance(addresses[0]);
        assertTrue(approximatelyEqual(issuance, 27 * CRC, EPS));

        _forwardTime(1 hours + 40 minutes);
        issuance = circles.calculateIssuance(addresses[0]);
        assertTrue(approximatelyEqual(issuance, 28 * CRC, EPS));

        vm.prank(addresses[0]);
        circles.claimIssuance();
        uint256 balance = circles.balanceOf(addresses[0], circlesIdentifiers[0]);
        assertTrue(approximatelyEqual(balance, 28 * CRC, EPS));
    }

    function testDemurragedTransfer() public {
        _forwardTime(12 * 24 hours + 1 minutes);

        for (uint256 i = 0; i < 2; i++) {
            uint256 expectedIssuance = circles.calculateIssuance(addresses[i]);
            vm.prank(addresses[i]);
            circles.claimIssuance();
            uint256 balance = circles.balanceOf(addresses[i], circlesIdentifiers[i]);
            assertEq(balance, expectedIssuance);
        }

        // send 5 CRC from alice to bob
        uint256 aliceBalance = circles.balanceOf(addresses[0], circlesIdentifiers[0]);
        uint256 bobBalance = circles.balanceOf(addresses[1], circlesIdentifiers[0]);
        // uint256 aliceInflationaryBalance = circles.inflationaryBalanceOf(addresses[0], circlesIdentifiers[0]);
        // uint256 bobInflationaryBalance = circles.inflationaryBalanceOf(addresses[1], circlesIdentifiers[0]);
        vm.prank(addresses[0]);
        circles.safeTransferFrom(addresses[0], addresses[1], circlesIdentifiers[0], 5 * CRC, "");
        uint256 aliceBalanceAfter = circles.balanceOf(addresses[0], circlesIdentifiers[0]);
        uint256 bobBalanceAfter = circles.balanceOf(addresses[1], circlesIdentifiers[0]);
        // uint256 aliceInflationaryBalanceAfter = circles.inflationaryBalanceOf(addresses[0], circlesIdentifiers[0]);
        // uint256 bobInflationaryBalanceAfter = circles.inflationaryBalanceOf(addresses[1], circlesIdentifiers[0]);
        assertEq(aliceBalance - 5 * CRC, aliceBalanceAfter);
        assertEq(bobBalance + 5 * CRC, bobBalanceAfter);
        // assertEq(
        //     aliceInflationaryBalance - aliceInflationaryBalanceAfter,
        //     bobInflationaryBalanceAfter - bobInflationaryBalance
        // );
    }

    // Private functions

    function _setUpTime(uint256 _time) internal {
        vm.warp(_time);
    }

    function _forwardTime(uint256 _duration) internal {
        vm.warp(block.timestamp + _duration);
    }
}
