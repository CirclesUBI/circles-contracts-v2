// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/migration/IHub.sol";
import "../../src/hub/Hub.sol";
import "../../src/migration/IHub.sol";

contract MockPathTransferHub is Hub {
    // Constructor

    constructor(uint256 _inflationDayZero, uint256 _bootstrapTime)
        Hub(IHubV1(address(1)), address(0), _inflationDayZero, address(1), _bootstrapTime, "")
    {}

    // External functions

    function registerHumanUnrestricted() external {
        address human = msg.sender;

        // insert avatar into linked list; reverts if it already exists
        _insertAvatar(human);

        // set the last mint time to the current timestamp for invited human
        // and register the v1 Circles contract status as unregistered
        address v1CirclesStatus = address(0);
        MintTime storage mintTime = mintTimes[human];
        mintTime.mintV1Status = v1CirclesStatus;
        mintTime.lastMintTime = uint96(block.timestamp);

        // trust self indefinitely, cannot be altered later
        _trust(human, human, INDEFINITE_FUTURE);
    }

    // Public functions

    function accessUnpackCoordinates(bytes calldata _packedData, uint256 _numberOfTriplets)
        public
        pure
        returns (uint16[] memory unpackedCoordinates_)
    {
        return super._unpackCoordinates(_packedData, _numberOfTriplets);
    }

    // Private functions

    function notMocked() private pure {
        assert(false);
    }
}
