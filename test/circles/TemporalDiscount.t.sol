// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "./MockTimeCircles.sol";
import "../../src/circles/TemporalDiscount.sol";
import "../../src/lib/Math64x64.sol";

contract TemporalDiscountTest is Test {
    // Constants
    uint256 public constant TIC = uint256(10 ** 18);

    // State variables
    MockTimeCircles public mockTimeCircles;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Setup function
    function setUp() public {
        mockTimeCircles = new MockTimeCircles(alice);
        // set the clock one second after zero time
        _setUpTime(mockTimeCircles.zeroTime() + 1);

        // Providing Alice with some tokens to start with
        mockTimeCircles.mint(10 * TIC);
    }

    function testTransferUpdatesBalancesWithoutDiscount() public {
        // Alice's initial balance should be 10 TIC
        assertEq(mockTimeCircles.balanceOf(alice), 10 * TIC);

        // Bob's initial balance should be 0
        assertEq(mockTimeCircles.balanceOf(bob), 0);

        // Perform the transfer from Alice to Bob
        vm.prank(alice); // Make the next call come from Alice's address
        mockTimeCircles.transfer(bob, 2 * TIC);

        // Check Alice's balance after the transfer
        assertEq(mockTimeCircles.balanceOf(alice), 8 * TIC, "Alice's balance should have decreased by 2 TIC.");

        // Check Bob's balance after the transfer
        assertEq(mockTimeCircles.balanceOf(bob), 2 * TIC, "Bob's balance should be increased by 2 TIC.");
    }

    function testTransferAfterDiscountUpdatesBalancesCorrectly() public {
        uint256 aliceOriginalBalance = 10 * TIC;

        // Given Alice has 10 TIC initially
        assertEq(mockTimeCircles.balanceOf(alice), aliceOriginalBalance, "Alice should start with 10 TIC");

        // calculate Alice's expected balance after discounting one window
        uint256 aliceExpectedBalanceAfterDiscount = _calculateDiscountedBalance(aliceOriginalBalance, 1);
        // wait for the next discount window
        _waitForNextDiscountWindow();

        uint256 aliceEffectiveBalanceAfterDiscount = mockTimeCircles.balanceOf(alice);
        assertEq(
            aliceEffectiveBalanceAfterDiscount,
            aliceExpectedBalanceAfterDiscount,
            "Alice's balance should read the discounted balance, less than 10 TIC."
        );
        // upon reading the balance, nothing is stored and no event for discounting is emitted
        // todo: vm.expectEmit crashes the solidity compiler, so ... fix forge?
        // uint256 aliceExpectedDiscountCost = aliceOriginalBalance - aliceExpectedBalanceAfterDiscount;

        // Given Bob initially has 0 tokens
        assertEq(mockTimeCircles.balanceOf(bob), 0, "Bob should start with 0 TIC");

        // When Alice transfers some tokens to Bob after discounting
        uint256 amountToTransfer = 2 * TIC; // This is the nominal amount without discount
        vm.prank(alice); // Make the next call come from Alice's address

        // Expect Alice's balance to be discounted first
        // vm.expectEmit(true, true, true, false);
        // emit TemporalDiscount.DiscountCost(alice, aliceExpectedDiscountCost);
        // Don't expect Bob's balance (= 0) to be discounted
        // Expect Transfer event from Alice to Bob
        // vm.expectEmit(true, true, true, true);
        // emit TemporalDiscount.Transfer(alice, bob, amountToTransfer);

        // Perform the transfer and check the events
        mockTimeCircles.transfer(bob, amountToTransfer);

        // Then Alice's balance should decrease by the transferred amount
        uint256 aliceEffectiveNewBalance = mockTimeCircles.balanceOf(alice);
        assertEq(
            aliceEffectiveNewBalance,
            aliceExpectedBalanceAfterDiscount - amountToTransfer,
            "Alice's balance should decrease by the transferred amount"
        );

        // And Bob should receive the transferred amount
        assertEq(mockTimeCircles.balanceOf(bob), amountToTransfer, "Bob should receive the transferred amount");
    }

    // Private functions

    // Private helper function to set up the blockchain time
    function _setUpTime(uint256 _startTime) private {
        // Move the blockchain time to _startTime
        vm.warp(_startTime);
    }

    function _waitForNextDiscountWindow() private {
        // wait for one week and one second
        uint256 oneWeekAndOneSecond = mockTimeCircles.DISCOUNT_WINDOW() + 1;
        skip(oneWeekAndOneSecond);
    }

    function _calculateDiscountedBalance(uint256 _balance, uint256 _exponent)
        private
        view
        returns (uint256 discountedBalance_)
    {
        int128 reduction64x64 = Math64x64.pow(mockTimeCircles.GAMMA_64x64(), _exponent);
        return discountedBalance_ = Math64x64.mulu(reduction64x64, _balance);
    }
}
