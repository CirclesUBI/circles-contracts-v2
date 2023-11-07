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

    // Setup function
    function setUp() public {
        mockTimeCircles = new MockTimeCircles(alice);
        // set the clock one second after zero time
        setUpTime(mockTimeCircles.zeroTime() + 1);
        
        // Providing Alice with some tokens to start with
        mockTimeCircles.mint(10 * EXA);
    }

    // Unit test to verify that the balances are updated correctly after a transfer
    function testTransferUpdatesBalances() public {
        // Alice's initial balance should be 10 EXA
        assertEq(mockTimeCircles.balanceOf(alice), 10 * EXA);

        // Bob's initial balance should be 0
        assertEq(mockTimeCircles.balanceOf(bob), 0);

        // Perform the transfer from Alice to Bob
        vm.prank(alice); // Make the next call come from Alice's address
        mockTimeCircles.transfer(bob, 2 * EXA);

        // Check Alice's balance after the transfer
        assertEq(mockTimeCircles.balanceOf(alice), 8 * EXA, "Alice's balance should have decreased by 2 EXA.");

        // Check Bob's balance after the transfer
        assertEq(mockTimeCircles.balanceOf(bob), 2 * EXA, "Bob's balance should be increased by 2 EXA.");
    }

    // Private helper function to set up the blockchain time
    function setUpTime(uint256 _startTime) private {
        // Move the blockchain time to _startTime
        vm.warp(_startTime);
    }
}