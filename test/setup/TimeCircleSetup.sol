// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../../src/mint/MintSplitter.sol";
import "../../src/graph/Graph.sol";
import "../../src/circles/TimeCircle.sol";
import "../../src/circles/GroupCircle.sol";
import "../migration/MockHub.sol";
import "./TimeSetup.sol";

contract TimeCircleSetup is TimeSetup {
    // Constants
    uint256 public constant TIC = uint256(10 ** 18);

    // State variables
    TimeCircle public masterCopyTimeCircle;
    GroupCircle public masterCopyGroupCircle;

    MockHubV1 public mockHubV1;
    MintSplitter public mintSplitter;
    Graph public graph;

    // address alice = makeAddr("alice");
    // address bob = makeAddr("bob");

    // Setup function
    function setUp() public {
        // no need to call setup() on master copy
        masterCopyTimeCircle = new TimeCircle();
        masterCopyGroupCircle = new GroupCircle();
        mockHubV1 = new MockHubV1();
        mintSplitter = new MintSplitter(mockHubV1);
        // create a new graph without ancestor circle migration
        graph = new Graph(mintSplitter, address(0), masterCopyTimeCircle, masterCopyGroupCircle);
        startTime();
    }
}
