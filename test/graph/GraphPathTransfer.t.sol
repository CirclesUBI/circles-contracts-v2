// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../../src/graph/Graph.sol";
import "../../src/graph/ICircleNode.sol";
import "../../src/circles/TimeCircle.sol";
import "../setup/TimeSetup.sol";
import "./MockHubV1.sol";

contract GraphPathTransferTest is Test, TimeSetup {
    // State variables

    TimeCircle public masterContractTimeCircle;

    MockHubV1 public mockHubV1;

    Graph public graph;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david");

    function setUp() public {
        // no need to call setup() on master copy
        masterContractTimeCircle = new TimeCircle();

        mockHubV1 = new MockHubV1();

        graph = new Graph(mockHubV1, masterContractTimeCircle);

        startTime();

        vm.prank(alice);
        graph.registerAvatar();
        vm.prank(bob);
        graph.registerAvatar();
        vm.prank(charlie);
        graph.registerAvatar();
        vm.prank(david);
        graph.registerAvatar();
        // they all get an initial signup bonus
    }

    function testSinglePathTransfer() public {
        
    }


    // Private functions

    // Private helper function to set up the blockchain time
    function _setUpTime(uint256 _startTime) private {
        // Move the blockchain time to _startTime
        vm.warp(_startTime);
    }
}