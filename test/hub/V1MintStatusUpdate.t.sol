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
        skipTime(5 days + 1 hours + 31 minutes);

        uint256 mintedAlice = mintV1Tokens(tokenAlice);
        uint256 mintedBob = mintV1Tokens(tokenBob);
        // mints 42799999999999536000 CRC
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

        // Alice invites Bob, while he is still active in V1
        vm.prank(addresses[0]);
        mockHub.inviteHuman(addresses[1]);
        require(mockHub.isHuman(addresses[1]), "Bob not registered");

        uint256 previousEndPeriod = 0;

        for (uint256 i = 0; i < 5; i++) {
            // Calculate issuance to get the current start and end periods
            (, uint256 startPeriod, uint256 endPeriod) = mockHub.calculateIssuance(addresses[0]);

            // For iterations after the first, check if the previous endPeriod matches the current startPeriod
            if (i > 0) {
                require(previousEndPeriod == startPeriod, "EndPeriod does not match next StartPeriod");
            }

            // Update previousEndPeriod with the current endPeriod for the next iteration
            previousEndPeriod = endPeriod;

            // Generate a pseudo-random number between 1 and 4
            uint256 hoursSkip = uint256(keccak256(abi.encodePacked(block.timestamp, i, uint256(0)))) % 4 + 1;
            uint256 secondsSkip = uint256(keccak256(abi.encodePacked(block.timestamp, i, uint256(1)))) % 3600;

            // Simulate passing of time variable windows of time (1-5 hours)
            skipTime(hoursSkip * 1 hours + secondsSkip);

            // Perform the mint operation as Alice
            vm.prank(addresses[0]);
            mockHub.personalMint();
        }

        // move time
        skipTime(5 days - 31 minutes);

        // Alice can mint in V2
        vm.startPrank(addresses[0]);
        mockHub.personalMint();

        //
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

    // function mintV2Circles(address _avatar) private returns (uint256) {
    //     // we can't check on the data (which contains id and amount),
    //     // because we don't know the amount upfront.
    //     vm.expectEmit(false, true, true, false);
    //     emit IERC1155.TransferSingle(_avatar, address(0), _avatar, uint256(uint160(_avatar)), 1);

    // }
}
