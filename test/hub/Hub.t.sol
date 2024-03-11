// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "../setup/TimeSetup.sol";
import "../setup/HumanRegistration.sol";
import "./MockPathTransferHub.sol";

contract HubPathTransferTest is Test, TimeSetup, HumanRegistration {
    // Constants

    uint256 public constant CRC = uint256(10 ** 18);

    // State variables

    MockPathTransferHub public mockHub;

    constructor() HumanRegistration(4) {}

    // Setup

    function setUp() public {
        // set time to 10 december 2021
        startTime();
        // create v2 Hub with 15 october 2020 as inflation day zero
        // and 365 days as bootstrap time
        mockHub = new MockPathTransferHub(INFLATION_DAY_ZERO, 365 days);

        // register 4 humans
        for (uint256 i = 0; i < N; i++) {
            vm.prank(addresses[i]);
            mockHub.registerHumanUnrestricted();
            assertEq(mockHub.isTrusted(addresses[i], addresses[i]), true);
        }
        // skip time to claim Circles
        skipTime(2 days + 1 minutes);

        for (uint256 i = 0; i < N; i++) {
            vm.prank(addresses[i]);
            mockHub.personalMintWithoutV1Check();
            assertEq(mockHub.balanceOf(addresses[i], mockHub.toTokenId(addresses[i])), 47985696851874424310);
        }

        // get this value first to avoid using `startPrank` over inline calls
        uint96 expiry = mockHub.INDEFINITE_FUTURE();

        // David trust (->) Charlie, C -> B, B -> A
        // so that Alice can send tokens to David over A-B-C-D
        for (uint256 i = N - 1; i > 0; i--) {
            vm.prank(addresses[i]);
            mockHub.trust(addresses[i - 1], expiry);
            assertEq(mockHub.isTrusted(addresses[i], addresses[i - 1]), true);
            assertEq(mockHub.isTrusted(addresses[i - 1], addresses[i]), false);
        }
    }

    // Tests

    function testOperateFlowMatrix() public {}
}
