// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../setup/TimeCircleSetup.sol";

contract TimeCircleTest is Test, TimeCircleSetup {
    function testFactorySetupTimeCircle() public {
        address edgar = makeAddr("Edgar");
        vm.prank(edgar);
        graph.registerAvatar();

        TimeCircle timeCircle = TimeCircle(address(graph.avatarToCircle(edgar)));
        // Verify that the `graph` state variable is set correctly
        assertEq(address(timeCircle.graph()), address(graph));
        // Verify that the `avatar` state variable is set correctly
        assertEq(timeCircle.avatar(), edgar);
    }

    function testSetupCannotBeCalledAgain() public {
        address edgar = makeAddr("Edgar");
        address notEdgar = makeAddr("notEdgar");
        vm.prank(edgar);
        graph.registerAvatar();

        TimeCircle timeCircle = TimeCircle(address(graph.avatarToCircle(edgar)));
        vm.expectRevert("Time Circle contract has already been setup.");
        timeCircle.setup(notEdgar);
    }
}
