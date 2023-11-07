// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "./MockTimeCircles.sol";

contract TemporalDiscountTest is Test {
    
    // Constants
    
    uint256 public constant EXA = uint256(10**18);

    // State variables

    MockTimeCircles public mockTimeCircles;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Public functions

    function setUp() public {
        mockTimeCircles = new MockTimeCircles(alice);
        // set the clock one second after zero time
        setUpTime(mockTimeCircles.zeroTime() + 1);
    }

    function test_SimpleMint() public {
        // mint one token for Alice
        mockTimeCircles.mint(1 * EXA);
        assertEq(mockTimeCircles.balanceOf(alice), EXA);
    }

    function testFail_SimpleDiscounting() public {
        // mint one token for Alice
        mockTimeCircles.mint(1 * EXA);
        assertEq(mockTimeCircles.balanceOf(alice), EXA);
        uint256 waitOneWeekAndOneSecond =
            mockTimeCircles.DISCOUNT_WINDOW() + 1;
        skip(waitOneWeekAndOneSecond);
        assertEq(mockTimeCircles.balanceOf(alice), EXA);
    }

    // function

    // Private functions

    function setUpTime(uint256 _startTime) private {
        // note: vm.wrap is not visible... ?
        //       so abuse skip to set the time
        skip(_startTime - block.timestamp);
    }
}