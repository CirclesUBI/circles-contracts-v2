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
    address[N] public sortedAddresses;
    uint256[N] public permutationMap;

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

        // all participants should have 48 TIC as signup bonus
        // todo: test this as separate unit test in graph.t.sol
        for (uint256 i = 0; i < N; i++) {
            assertEq(circleNodes[i].balanceOf(addresses[i]), masterContractTimeCircle.TIME_BONUS() * TIC);
        }

        // to build a correct flow matrix, we need to present the vertices
        // in ascending order, so sort the addresses and store the permutation map
        sortAddressesWithPermutationMap();

        // make a linear trust graph D->C->B->A
        makeLinearTrustGraph();
    }

    function testSinglePathTransfer() public {
        // Flow matrix for transferring tokens from Alice to David
        //       A    B    C    D
        // A-B  -5    5    -    -
        // B-C   -   -5    5    -
        // C-D   -    -   -5    5

        address[] memory flowVertices = new address[](N);
        uint256[] memory flow = new uint256[](N - 1);

        // allocate three coordinates per flow edge
        uint16[] memory coordinates = new uint16[]((N - 1) * 3);

        // the flow vertices need to be provided in ascending order
        for (uint256 i = 0; i < N; i++) {
            flowVertices[i] = sortedAddresses[i];
        }

        // track the coordinate index
        uint256 index = 0;

        // for each row in the flow matrix specify the coordinates and amount
        for (uint256 i = 0; i < N - 1; i++) {
            // this is easy, the amount is constant for each edge
            flow[i] = uint256(5 * TIC);
            // first index indicates the token to use
            // for our example we start with Alice, and end with Charlie
            coordinates[index++] = uint16(permutationMap[i]);
            // the second coordinate refers to the sender,
            // which is the same as token of avatar for our example
            coordinates[index++] = uint16(permutationMap[i]);
            // the third coordinate specifies the receiver
            coordinates[index++] = uint16(permutationMap[i + 1]);
        }

        // let's pack the coordinates into bytes
        bytes memory packedCoordinates = packCoordinates(coordinates);

        // send from Alice
        vm.prank(addresses[0]);
        graph.singlePathTransfer(
            uint16(permutationMap[0]), // from Alice
            uint16(permutationMap[3]), // to David
            uint256(5 * TIC), // send 5 Time Circles
            flowVertices,
            flow,
            packedCoordinates
        );
    }

    // Private functions

    /**
     * @dev Sorts an array of addresses in ascending order using Bubble Sort
     *      and returns the permutation map. This is not meant to be an efficient sort,
     *      rather the simplest implementation for transparancy of the test.
     */
    function sortAddressesWithPermutationMap() private {
        uint256 length = addresses.length;
        sortedAddresses = addresses;
        // permutationMap = new uint[N];

        // Initialize the permutation map with original indices
        for (uint256 i = 0; i < length; i++) {
            permutationMap[i] = i;
        }

        // Bubble sort the array and the permutation map
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (sortedAddresses[j] > sortedAddresses[j + 1]) {
                    // Swap elements in the address array
                    (sortedAddresses[j], sortedAddresses[j + 1]) = (sortedAddresses[j + 1], sortedAddresses[j]);
                    // Swap corresponding elements in the permutation map
                    (permutationMap[j], permutationMap[j + 1]) = (permutationMap[j + 1], permutationMap[j]);
                }
            }
        }
    }

    /**
     * @dev Packs an array of uint16 coordinates into bytes.
     * Each coordinate is represented as 16 bits (2 bytes).
     * @param _coordinates The array of uint16 coordinates.
     * @return packedData_ The packed coordinates as bytes.
     */
    function packCoordinates(uint16[] memory _coordinates) private pure returns (bytes memory packedData_) {
        packedData_ = new bytes(_coordinates.length * 2);

        for (uint256 i = 0; i < _coordinates.length; i++) {
            packedData_[2 * i] = bytes1(uint8(_coordinates[i] >> 8)); // High byte
            packedData_[2 * i + 1] = bytes1(uint8(_coordinates[i] & 0xFF)); // Low byte
        }
    }

    function makeLinearTrustGraph() private {
        // David trust (->) Charlie, C -> B, B -> A
        // so that Alice can send tokens to David over A-B-C-D
        for (uint256 i = N - 1; i > 0; i--) {
            vm.prank(addresses[i]);
            graph.trust(addresses[i - 1]);
            assertEq(graph.isTrusted(addresses[i], addresses[i - 1]), true);
            assertEq(graph.isTrusted(addresses[i - 1], addresses[i]), false);
        }
    }
}
