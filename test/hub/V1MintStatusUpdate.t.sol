// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "../../src/migration/Migration.sol";
import "../setup/TimeCirclesSetup.sol";
import "../setup/HumanRegistration.sol";
import "../migration/MockHub.sol";
import "./MockMigrationHub.sol";

contract V1MintStatusUpdateTest is Test, TimeCirclesSetup, HumanRegistration {
    // Constants

    bytes32 private constant SALT = keccak256("CirclesV2:V1MintStatusUpdateTest");

    // State variables

    MockMigrationHub public mockHub;
    MockHubV1 public mockHubV1;

    Migration public migration;

    // Constructor

    constructor() HumanRegistration(2) {}

    // Setup

    function setUp() public {
        startTime();

        mockHubV1 = new MockHubV1();
        migration = new Migration(address(mockHubV1), address(1), INFLATION_DAY_ZERO, 365 days);
        mockHub = new MockMigrationHub(mockHubV1, address(2), INFLATION_DAY_ZERO, 365 days);

    }

    // Tests

    function testMigrationFromV1DuringBootstrap() public {

    }

    // Private functions

    function _calculateContractAddress(address _deployer, uint256 _nonce) private returns (address) {
        // predict the contract addresses
       bytes memory input = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _deployer, _nonce);
    }
}
