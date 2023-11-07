// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "./MockTimeCircles.sol";
import "../../src/circles/TemporalDiscount.sol";
import "../../src/lib/Math64x64.sol";

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
    // within the same discounting window
    function testTransferUpdatesBalancesWithoutDiscount() public {
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

        // Unit test to verify that balances are correctly updated after discount and transfer,
    // and that the correct events are emitted
    function testTransferAfterDiscountUpdatesBalancesCorrectly() public {
        // Given Alice has 10 EXA initially
        assertEq(mockTimeCircles.balanceOf(alice), 10 * EXA, "Alice should start with 10 EXA");

        // When we wait for the next discount window
        waitForNextDiscountWindow();

        // Expect DiscountCost event for Alice's discount
        vm.expectEmit(true, true, false);
        emit TemporalDiscount.DiscountCost(alice, 1); // We expect any cost here since we don't know the exact discount amount
        
        // Check Alice's balance after the discount to verify the event
        uint256 aliceBalanceAfterDiscount = mockTimeCircles.balanceOf(alice);
        assertTrue(aliceBalanceAfterDiscount < 10 * EXA, "Alice's balance should be discounted");

        // Given Bob initially has 0 tokens
        assertEq(mockTimeCircles.balanceOf(bob), 0, "Bob should start with 0 tokens");

        // When Alice transfers some tokens to Bob after discounting
        uint256 amountToTransfer = 2 * EXA; // This is the nominal amount without discount
        vm.prank(alice); // Make the next call come from Alice's address

        // Expect Transfer event from Alice to Bob
        vm.expectEmit(true, true, true, true);
        emit TemporalDiscount.Transfer(alice, bob, amountToTransfer);
        
        // Perform the transfer and check the events
        mockTimeCircles.transfer(bob, amountToTransfer);

        // Then Alice's balance should decrease by the transferred amount
        uint256 aliceNewBalance = mockTimeCircles.balanceOf(alice);
        assertEq(aliceNewBalance, aliceBalanceAfterDiscount - amountToTransfer, "Alice's balance should decrease by the transferred amount");

        // And Bob should receive the transferred amount
        assertEq(mockTimeCircles.balanceOf(bob), amountToTransfer, "Bob should receive the transferred amount");
    }

    // Private helper function to set up the blockchain time
    function setUpTime(uint256 _startTime) private {
        // Move the blockchain time to _startTime
        vm.warp(_startTime);
    }

    function waitForNextDiscountWindow() private {
        // wait for one week and one second
        uint256 oneWeekAndOneSecond = mockTimeCircles.DISCOUNT_WINDOW() + 1;
        skip(oneWeekAndOneSecond);
    }
}