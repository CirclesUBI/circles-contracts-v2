// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./IHub.sol";
import "./IToken.sol";
import "../graph/IGraph.sol";

contract CirclesMigration {
    // State variables

    IHubV1 public immutable hubV1;

    IGraph public immutable graphV2;

    uint256 public immutable inflation;
    uint256 public immutable divisor;
    uint256 public immutable deployedAt;
    uint256 public immutable initialIssuance;
    uint256 public immutable period;

    // Constructor

    // see for context prior discussions on the conversion of CRC to TC,
    // and some reference to the 8 CRC per day to 24 CRC per day gauge-reset
    // https://aboutcircles.com/t/conversion-from-crc-to-time-circles-and-back/463
    // the UI conversion used is found here:
    // https://github.com/circlesland/timecircle/blob/master/src/index.ts
    constructor(IHubV1 _hubV1, IGraph _graphV2) {
        require(address(_hubV1) != address(0), "Hub v1 address can not be zero.");
        require(address(_graphV2) != address(0), "Graph v2 address can not be zero.");

        hubV1 = _hubV1;
        graphV2 = _graphV2;

        // from deployed v1 contract SHOULD return inflation = 107
        inflation = hubV1.inflation();
        // from deployed v1 contract SHOULD return divisor = 100
        divisor = hubV1.divisor();
        // from deployed v1 contract SHOULD return deployedAt = 1602786330
        // (for reference 6:25:30 pm UTC  |  Thursday, October 15, 2020)
        deployedAt = hubV1.deployedAt();
        // from deployed v1 contract SHOULD return initialIssuance = 92592592592592
        // (equivalent to 1/3 CRC per hour; original at launch 8 CRC per day)
        // later it was decided that 24 CRC per day, or 1 CRC per hour should be the standard gauge
        // and the correction was done at the interface level, so everyone sees their balance
        // corrected for 24 CRC/day; we should hence adopt this correction in the token migration step.
        initialIssuance = hubV1.initialIssuance();
        // from deployed v1 contract SHOULD return period = 31556952
        // (equivalent to 365 days 5 hours 49 minutes 12 seconds)
        // because the period is not a whole number of hours,
        // the interval of hub v1 will not match the periodicity of any hour-based period in v2.
        period = hubV1.period();
    }

    // External functions

    /**
     * @param _depositAmount Deposit amount specifies the amount of inflationary
     *     hub v1 circles the caller wants to convert and migrate to demurraged Circles.
     *     One can only convert personal v1 Circles, if that person has stopped their v1
     *     circles contract, and has created a v2 demurraged Circles contract by registering in v2.
     */
    function convertAndMigrateCircles(ITokenV1 _originCircle, uint256 _depositAmount)
        external
        returns (uint256 mintedAmount_)
    {
        // first check the existance of the origin Circle and whether it is stopped
        require(checkOriginCircleStopped(_originCircle), "Origin Circle must have been stopped before conversion.");

        // calculate inflationary correction
    }

    // Public functions

    function checkOriginCircleStopped(ITokenV1 _originCircle) public returns (bool stopped_) {
        require(hubV1.tokenToUser(address(_originCircle)) != address(0), "Origin Circle is not registered in hub V1.");

        return stopped_ = _originCircle.stopped();
    }

    // Private functions

    function convertFromV1ToTimeCircles(uint256 _amount) private returns (uint256 timeCircleAmount_) {
        uint256 currentPeriod = hubV1.periods();
        uint256 nextPeriod = currentPeriod + 1;

        uint256 startOfPeriod = hubV1.deployedAt() + currentPeriod * hubV1.period();

        // number of seconds into the new period
        uint256 secondsIntoCurrentPeriod = block.timestamp - startOfPeriod;

        
    }
}
