// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../../src/graph/Graph.sol";
import "../../src/graph/ICircleNode.sol";
import "../../src/circles/TimeCircle.sol";
import "./MockHubV1.sol";

contract GraphTest is Test {

    // State variables
    
    TimeCircle public masterContractTimeCircle;

    MockHubV1 public mockHubV1;

    Graph public graph;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setup() public {

        // no need to call setup() on master copy
        masterContractTimeCircle = new TimeCircle();

        mockHubV1 = new MockHubV1();

        graph = new Graph(mockHubV1, masterContractTimeCircle);
    }

    
}