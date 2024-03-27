// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/migration/IToken.sol";
import "../migration/MockMigration.sol";
import "../names/MockNameRegistry.sol";
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

    MockNameRegistry public nameRegistry;
    MockMigration public migration;

    // Constructor

    constructor() HumanRegistration(2) {}

    // Setup

    function setUp() public {
        // Set time in 2021
        startTime();

        mockHubV1 = new MockHubV1();
        // First deploy the contracts to know the addresses
        migration = new MockMigration(mockHubV1, IHubV2(address(1)));
        nameRegistry = new MockNameRegistry(IHubV2(address(1)));
        mockHub = new MockMigrationHub(mockHubV1, address(2), INFLATION_DAY_ZERO, 365 days);
        // then set the addresses in the respective contracts
        migration.setHubV2(IHubV2(address(mockHub)));
        nameRegistry.setHubV2(IHubV2(address(mockHub)));
        mockHub.setSiblings(address(migration), address(nameRegistry));
    }

    // Tests

    function testMigrationFromV1DuringBootstrap() public {
        // Alice and Bob register in V1
        ITokenV1 tokenAlice = signupInV1(addresses[0]);
        ITokenV1 tokenBob = signupInV1(addresses[1]);

        // move time
        skipTime(30 days);

        uint256 mintedAlice = mintV1Tokens(tokenAlice);
        uint256 mintedBob = mintV1Tokens(tokenBob);
        // mints 256799999999997216000 CRC
        // which is 8.5599999999999072 CRC per day
        console.log("mintedAlice", mintedAlice);
        console.log("mintedBob", mintedBob);

        // Alice stops her V1 token and registers in V2
        vm.startPrank(addresses[0]);
        tokenAlice.stop();
        require(tokenAlice.stopped(), "Token not stopped");
        mockHub.registerHuman(bytes32(0));
        vm.stopPrank();
        require(mockHub.isHuman(addresses[0]), "Alice not registered");
    }

    // Private functions

    function signupInV1(address _user) private returns (ITokenV1) {
        vm.prank(_user);
        mockHubV1.signup();
        ITokenV1 token = ITokenV1(mockHubV1.userToToken(_user));
        require(address(token) != address(0), "Token not minted");
        require(token.owner() == _user, "Token not owned by user");
        return token;
    }

    function mintV1Tokens(ITokenV1 _token) private returns (uint256) {
        address owner = _token.owner();
        uint256 balanceBefore = _token.balanceOf(owner);
        ITokenV1(_token).update();
        uint256 balanceAfter = _token.balanceOf(owner);
        return balanceAfter - balanceBefore;
    }
}
