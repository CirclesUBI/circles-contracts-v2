// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

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
        startTime();
        mockHub = new MockPathTransferHub(INFLATION_DAY_ZERO, 365 days);
    }

    // Tests

    function testOperateFlowMatrix() public {}
}
