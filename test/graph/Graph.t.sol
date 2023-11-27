// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../../src/graph/Graph.sol";
import "../../src/graph/ICircleNode.sol";
import "../../src/circles/TimeCircle.sol";
import "../../src/circles/GroupCircle.sol";
import "./MockHubV1.sol";
import "./MockInternalGraph.sol";

contract GraphTest is Test {
    // State variables

    TimeCircle public masterCopyTimeCircle;

    GroupCircle public masterCopyGroupCircle;

    MockHubV1 public mockHubV1;

    Graph public graph;

    MockInternalGraph public mockInternalGraph;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // no need to call setup() on master copy
        masterCopyTimeCircle = new TimeCircle();

        masterCopyGroupCircle = new GroupCircle();

        mockHubV1 = new MockHubV1();

        graph = new Graph(mockHubV1, masterCopyTimeCircle, masterCopyGroupCircle);

        mockInternalGraph = new MockInternalGraph(mockHubV1, masterCopyTimeCircle, masterCopyGroupCircle);
    }

    function testUnpackCoordinates() public {
        // Example: prepare packed data for two triplets (each coordinate is 16 bits)
        // First triplet: (1, 2, 3), Second triplet: (4, 5, 6)
        bytes memory packedData = new bytes(12);
        packedData[0] = bytes1(uint8(0));
        packedData[1] = bytes1(uint8(1));
        packedData[2] = bytes1(uint8(0));
        packedData[3] = bytes1(uint8(2));
        packedData[4] = bytes1(uint8(0));
        packedData[5] = bytes1(uint8(3));
        packedData[6] = bytes1(uint8(0));
        packedData[7] = bytes1(uint8(4));
        packedData[8] = bytes1(uint8(0));
        packedData[9] = bytes1(uint8(5));
        packedData[10] = bytes1(uint8(0));
        packedData[11] = bytes1(uint8(6));

        uint16[] memory unpacked = mockInternalGraph.accessUnpackCoordinates(packedData, 2);

        // Assertions to ensure correct unpacking
        assertEq(unpacked[0], 1);
        assertEq(unpacked[1], 2);
        assertEq(unpacked[2], 3);
        assertEq(unpacked[3], 4);
        assertEq(unpacked[4], 5);
        assertEq(unpacked[5], 6);
    }
}
