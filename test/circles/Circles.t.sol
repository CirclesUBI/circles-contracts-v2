// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "./MockCircles.sol";
import "../setup/TimeCirclesSetup.sol";
import "../utils/Approximation.sol";

contract CirclesTest is Test, TimeCirclesSetup, Approximation {
    // Constants

    uint256 public constant N = 4;

    uint256 public constant EPS = 10 ** (18 - 2);
    uint256 public constant FEMTO_EPS = 10 ** (18 - 15);

    // State variables

    MockCircles public circles;

    string[N] public avatars = ["alice", "bob", "charlie", "david"];
    address[N] public addresses;
    uint256[N] public circlesIdentifiers;

    // Public functions

    function setUp() public {
        // set time to 15th October 2020
        startTime();

        circles = new MockCircles(INFLATION_DAY_ZERO);

        for (uint256 i = 0; i < N; i++) {
            addresses[i] = makeAddr(avatars[i]);
            circlesIdentifiers[i] = uint256(uint160(addresses[i]));
            circles.registerHuman(addresses[i]);
        }
    }

    function testCalculateIssuance() public {
        for (uint256 i = 0; i < 100; i++) {
            // Generate a pseudo-random number of seconds between 0 and 16 days (14days is max claimable period)
            uint256 secondsSkip = uint256(keccak256(abi.encodePacked(block.timestamp, i, uint256(2)))) % 16 days;

            _skipAndMint(secondsSkip, addresses[0]);
        }
    }

    function testConsecutiveClaimablePeriods() public {
        // skipTime(5 hours); // todo: investigate why startTime is zero is this commented out?

        uint256 previousEndPeriod = 0;

        for (uint256 i = 0; i < 10; i++) {
            // Calculate issuance to get the current start and end periods
            (, uint256 startPeriod, uint256 endPeriod) = circles.calculateIssuance(addresses[0]);

            // For iterations after the first, check if the previous endPeriod matches the current startPeriod
            if (i > 0) {
                assertEq(previousEndPeriod, startPeriod, "EndPeriod does not match next StartPeriod");
            }

            // Update previousEndPeriod with the current endPeriod for the next iteration
            previousEndPeriod = endPeriod;

            // Generate a pseudo-random number between 1 and 4
            uint256 hoursSkip = uint256(keccak256(abi.encodePacked(block.timestamp, i, uint256(0)))) % 4 + 1;
            uint256 secondsSkip = uint256(keccak256(abi.encodePacked(block.timestamp, i, uint256(1)))) % 3600;

            // Simulate passing of time variable windows of time (1-5 hours)
            skipTime(hoursSkip * 1 hours + secondsSkip);

            // Perform the mint operation as Alice
            vm.prank(addresses[0]);
            circles.claimIssuance();
        }

        uint256 balanceOfAlice = circles.balanceOf(addresses[0], circlesIdentifiers[0]);

        // now mint for Bob in one go and test that Alice and Bob have the same balance
        vm.prank(addresses[1]);
        circles.claimIssuance();
        uint256 balanceOfBob = circles.balanceOf(addresses[1], circlesIdentifiers[1]);
        // the difference between Alice and Bob is less than dust
        assertTrue(approximatelyEqual(balanceOfAlice, balanceOfBob, FEMTO_EPS));
    }

    function testDemurragedTransfer() public {
        skipTime(12 * 24 hours + 1 minutes);

        for (uint256 i = 0; i < 2; i++) {
            (uint256 expectedIssuance,,) = circles.calculateIssuance(addresses[i]);
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

    function _skipAndMint(uint256 _seconds, address _avatar) private {
        // ensure the avatar has no issuance already to start with
        (uint256 issuance, uint256 startPeriod, uint256 endPeriod) = circles.calculateIssuance(_avatar);
        assertEq(issuance, 0, "Ensure avatar has no issuance");

        // skip time
        skipTime(_seconds);

        uint256 balanceBefore = circles.balanceOf(_avatar, uint256(uint160(_avatar)));
        (issuance, startPeriod, endPeriod) = circles.calculateIssuance(_avatar);
        uint256 hoursCount = (endPeriod - startPeriod) / 1 hours;
        // console.log("hoursCount", hoursCount, "days:", hoursCount / 24);
        vm.prank(_avatar);
        circles.claimIssuance();
        uint256 balanceAfter = circles.balanceOf(_avatar, uint256(uint160(_avatar)));
        assertEq(balanceAfter - balanceBefore, issuance, "Ensure issuance is minted");
        assertTrue(issuance <= hoursCount * CRC, "Ensure issuance is not more than expected");
        assertTrue(relativeApproximatelyEqual(issuance, hoursCount * CRC, ONE_PERCENT), "Ensure issuance is correct");
    }
}
