// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./IHub.sol";
import "./IToken.sol";
import "../graph/IGraph.sol";

contract CirclesMigration {
    // Constant

    uint256 private constant ACCURACY = uint256(10 ** 8);

    // State variables

    IHubV1 public immutable hubV1;

    // IGraph public immutable graphV2;

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
    constructor(IHubV1 _hubV1) {
        require(address(_hubV1) != address(0), "Hub v1 address can not be zero.");

        hubV1 = _hubV1;

        // from deployed v1 contract SHOULD return deployedAt = 1602786330
        // (for reference 6:25:30 pm UTC  |  Thursday, October 15, 2020)
        deployedAt = hubV1.deployedAt();
        // from deployed v1 contract SHOULD return period = 31556952
        // (equivalent to 365 days 5 hours 49 minutes 12 seconds)
        // because the period is not a whole number of hours,
        // the interval of hub v1 will not match the periodicity of any hour-based period in v2.
        period = hubV1.period();

        // note: currently these parameters are not used, remove them if they remain so

        // from deployed v1 contract SHOULD return inflation = 107
        inflation = hubV1.inflation();
        // from deployed v1 contract SHOULD return divisor = 100
        divisor = hubV1.divisor();
        // from deployed v1 contract SHOULD return initialIssuance = 92592592592592
        // (equivalent to 1/3 CRC per hour; original at launch 8 CRC per day)
        // later it was decided that 24 CRC per day, or 1 CRC per hour should be the standard gauge
        // and the correction was done at the interface level, so everyone sees their balance
        // corrected for 24 CRC/day; we should hence adopt this correction in the token migration step.
        initialIssuance = hubV1.initialIssuance();
    }

    // External functions

    /**
     * @param _depositAmount Deposit amount specifies the amount of inflationary
     *     hub v1 circles the caller wants to convert and migrate to demurraged Circles.
     *     One can only convert personal v1 Circles, if that person has stopped their v1
     *     circles contract, and has created a v2 demurraged Circles contract by registering in v2.
     */
    function convertAndMigrateCircles(ITokenV1 _originCircle, uint256 _depositAmount, IGraph _destinationGraph)
        external
        returns (uint256 mintedAmount_)
    {
        // First check the existance of the origin Circle, and associated avatar
        address avatar = hubV1.tokenToUser(address(_originCircle));
        require(avatar != address(0), "Origin Circle is unknown to hub v1.");

        // and whether the origin Circle has been stopped.
        require(_originCircle.stopped(), "Origin Circle must have been stopped before conversion.");

        // Retrieve the destination Circle where to migrate the tokens to
        IAvatarCircleNode destinationCircle = _destinationGraph.avatarToCircle(avatar);
        // and check it in fact exists.
        require(
            address(destinationCircle) != address(0),
            "Associated avatar has not been registered in the destination graph."
        );

        // Calculate inflationary correction towards time circles.
        uint256 convertedAmount = convertFromV1ToTimeCircles(_depositAmount);

        // transfer the tokens into a permanent lock in this contract
        // v1 Circle does not have a burn function exposed, so we can only lock them here
        _originCircle.transferFrom(msg.sender, address(this), _depositAmount);

        require(
            _destinationGraph.migrateCircles(msg.sender, convertedAmount, destinationCircle),
            "Destination graph must succeed at migrating the tokens."
        );
    }

    // Public functions

    function convertFromV1ToTimeCircles(uint256 _amount) public view returns (uint256 timeCircleAmount_) {
        uint256 currentPeriod = hubV1.periods();
        uint256 nextPeriod = currentPeriod + 1;

        uint256 startOfPeriod = deployedAt + currentPeriod * period;

        // number of seconds into the new period
        uint256 secondsIntoCurrentPeriod = block.timestamp - startOfPeriod;

        // rather than using initial issuance; use a clean order of magnitude
        // to calculate the conversion factor.
        // This is because initial issuance (originally ~ 8 CRC / day;
        // then corrected to 24 CRC / day) is ever so slightly less than 1 CRC / hour
        // ( 0.9999999999999936 CRC / hour to be precise )
        // but if we later divide by this, then the error is ever so slightly
        // in favor of converting - note there are many more errors,
        // but we try to have each error always be in disadvantage of v1 so that
        // there is no adverse incentive to mint and convert from v1
        uint256 factorCurrentPeriod = hubV1.inflate(ACCURACY, currentPeriod);
        uint256 factorNextPeriod = hubV1.inflate(ACCURACY, nextPeriod);

        // linear interpolation of inflation rate
        // r = x * (1 - a) + y * a
        // if a = secondsIntoCurrentPeriod / Period = s / P
        // => P * r = x * (P - s) + y * s
        uint256 rP =
            factorCurrentPeriod * (period - secondsIntoCurrentPeriod) + factorNextPeriod * secondsIntoCurrentPeriod;

        // account for the adjustment of the accepted gauge of 24 CRC / day,
        // rather than 8 CRC / day, so multiply by 3
        // and divide by the inflation rate to convert to temporally discounted units
        // (as if inflation would have been continuously adjusted. This is not the case,
        // it is only annually compounded, but the disadvantage is for v1 vs v2).
        return timeCircleAmount_ = (_amount * 3 * ACCURACY * period) / rP;
    }
}
