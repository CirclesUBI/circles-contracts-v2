// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../../src/mint/MintSplitter.sol";
import "../../src/graph/Graph.sol";
import "../../src/circles/TimeCircle.sol";
import "../../src/circles/GroupCircle.sol";
import "../migration/MockHub.sol";
import "./TimeCirclesSetup.sol";

contract TimeCircleSetup is TimeCirclesSetup {
    // Constants
    // number of avatars in the graph
    uint256 public constant N = 4;
    uint256 public constant TIC = uint256(10 ** 18);

    // State variables
    TimeCircle public masterCopyTimeCircle;
    GroupCircle public masterCopyGroupCircle;

    MockHubV1 public mockHubV1;
    MintSplitter public mintSplitter;
    Graph public graph;

    string[N] public avatars = ["alice", "bob", "charlie", "david"];
    address[N] public addresses;

    TimeCircle[N] public circleNodes;

    address[] public destinations;
    int128[] public allocations; // 100% in 64.64 signed fixed point representation is 2^64

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

        setupMintSplitter();
    }

    function setupMintSplitter() public {
        // all participants need to register their distribution to be destined for the graph
        // setup default destination and distribution
        destinations = new address[](1);
        destinations[0] = address(graph);
        allocations = new int128[](1);
        allocations[0] = int128(2 ** 64); // 100% in 64.64 signed fixed point representation is 2^64

        for (uint256 i = 0; i < N; i++) {
            addresses[i] = makeAddr(avatars[i]);
            vm.prank(addresses[i]);
            graph.registerAvatar();
            circleNodes[i] = TimeCircle(address(graph.avatarToCircle(addresses[i])));

            vm.prank(addresses[i]);
            mintSplitter.registerDistribution(destinations, allocations);
        }
    }
}
