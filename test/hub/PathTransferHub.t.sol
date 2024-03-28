// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "../../src/hub/Hub.sol";
import "../setup/TimeCirclesSetup.sol";
import "../setup/HumanRegistration.sol";
import "../utils/Approximation.sol";
import "./MockPathTransferHub.sol";

contract HubPathTransferTest is Test, TimeCirclesSetup, HumanRegistration, Approximation {
    // State variables

    MockPathTransferHub public mockHub;

    constructor() HumanRegistration(4) {}

    // Setup

    function setUp() public {
        // set time to 10 december 2021
        startTime();
        // create v2 Hub with 15 october 2020 as inflation day zero
        // and 365 days as bootstrap time
        mockHub = new MockPathTransferHub(INFLATION_DAY_ZERO, 365 days);

        // register 4 humans
        for (uint256 i = 0; i < N; i++) {
            vm.prank(addresses[i]);
            mockHub.registerHumanUnrestricted();
            assertEq(mockHub.isTrusted(addresses[i], addresses[i]), true);
        }
        // skip time to claim Circles
        skipTime(2 days + 1 minutes);

        for (uint256 i = 0; i < N; i++) {
            vm.prank(addresses[i]);
            mockHub.personalMintWithoutV1Check();
            uint256 balance = mockHub.balanceOf(addresses[i], mockHub.toTokenId(addresses[i]));
            assertTrue(relativeApproximatelyEqual(balance, 48 * CRC, ONE_PERCENT));
        }

        // get this value first to avoid using `startPrank` over inline calls
        uint96 expiry = type(uint96).max;

        // David trust (->) Charlie, C -> B, B -> A
        // so that Alice can send tokens to David over A-B-C-D
        for (uint256 i = N - 1; i > 0; i--) {
            vm.prank(addresses[i]);
            mockHub.trust(addresses[i - 1], expiry);
            assertEq(mockHub.isTrusted(addresses[i], addresses[i - 1]), true);
            assertEq(mockHub.isTrusted(addresses[i - 1], addresses[i]), false);
        }
    }

    // Tests

    function testOperateFlowMatrix() public {
        // Flow matrix for transferring Circles from Alice to David
        // with indication of which Circles are being sent
        //       A     B     C     D
        // A-B  -5A    5A    .     .
        // B-C   .    -5B    5B    .
        // C-D   .     .    -5C    5C

        address[] memory flowVertices = new address[](N);
        Hub.FlowEdge[] memory flow = new Hub.FlowEdge[](N - 1);

        // allocate three coordinates per flow edge
        uint16[] memory coordinates = new uint16[]((N - 1) * 3);

        // the flow vertices need to be provided in ascending order\
        for (uint256 i = 0; i < N; i++) {
            flowVertices[i] = sortedAddresses[i];
        }

        // the "flow matrix" is a rang three tensor:
        // Circles identifier, flow edge, and flow vertex (location)
        uint256 index = 0;

        // for each row in the flow matrix specify the coordinates and amount
        for (uint256 i = 0; i < N - 1; i++) {
            // flow is the amount of Circles to send, here constant for each edge
            flow[i].amount = uint240(5 * CRC);
            flow[i].streamSinkId = uint16(0);
            // first index indicates which Circles to use
            // for our example, we use the Circles of the sender
            coordinates[index++] = lookupMap[i];
            // the second coordinate refers to the sender
            coordinates[index++] = lookupMap[i];
            // the third coordinate specifies the receiver
            coordinates[index++] = lookupMap[i + 1];
        }

        // only the last flow edge is a terminal edge in this example to Charlie->David
        // and it then refers to the single stream Alice -> David of 5 (Charlie) Circles
        // start counting from 1, to reserve 0 for the non-terminal edges
        flow[2].streamSinkId = uint16(1);

        // we have to pack the coordinates into bytes
        bytes memory packedCoordinates = packCoordinates(coordinates);

        // Lastly we need to define the streams (only one from Alice to David)
        Hub.Stream[] memory streams = new Hub.Stream[](1);
        // the source coordinate for Alice
        streams[0].sourceCoordinate = lookupMap[0];
        // the flow edges that constitute the termination of this stream
        streams[0].flowEdgeIds = new uint16[](1);
        streams[0].flowEdgeIds[0] = uint16(2);
        // and optional data to pass to the receiver David from Alice
        streams[0].data = new bytes(0);

        // Alice needs to authorize the operator who sends the flow matrix
        // for the test she can approve herselve as an operator
        vm.prank(addresses[0]);
        mockHub.setApprovalForAll(addresses[0], true);

        // act as oeprator and send the flow matrix
        vm.prank(addresses[0]);
        mockHub.operateFlowMatrix(flowVertices, flow, streams, packedCoordinates);
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
}
