// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../setup/TimeCircleSetup.sol";

contract TimeCircleTest is Test, TimeCircleSetup {
    function testFactorySetupTimeCircle() public {
        string memory avatar = "Edgar";
    }
}
