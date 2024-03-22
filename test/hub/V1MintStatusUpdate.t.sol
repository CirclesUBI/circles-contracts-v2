// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../setup/TimeCirclesSetup.sol";
import "../setup/HumanRegistration.sol";

contract V1MintStatusUpdateTest is Test, TimeCirclesSetup, HumanRegistration {
    // State variables

    // Constructor

    constructor() HumanRegistration(2) {}

    // Setup

    function setUp() public {
        startTime();
    }
}
