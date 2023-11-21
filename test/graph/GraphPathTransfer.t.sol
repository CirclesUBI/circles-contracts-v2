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
    // Constant

    // number of avatars in the graph
    uint256 public constant N = 4;

    uint256 public constant TIC = uint256(10 ** 18);

    // State variables

    TimeCircle public masterContractTimeCircle;

    MockHubV1 public mockHubV1;

    Graph public graph;

    string[N] public avatars = ["alice", "bob", "charlie", "david"];
    address[N] public addresses;
    ICircleNode[N] public circleNodes;

    function setUp() public {
        // no need to call setup() on master copy
        masterContractTimeCircle = new TimeCircle();

        mockHubV1 = new MockHubV1();

        graph = new Graph(mockHubV1, masterContractTimeCircle);

        startTime();

        for (uint256 i = 0; i < N; i++) {
            addresses[i] = makeAddr(avatars[i]);
            vm.prank(addresses[i]);
            graph.registerAvatar();
            circleNodes[i] = graph.avatarToNode(addresses[i]);
        }
        // they all get an initial signup bonus
    }

    function testSinglePathTransfer() public {
        assertEq(circleNodes[0].balanceOf(addresses[0]), masterContractTimeCircle.TIME_BONUS() * TIC);
    }
}