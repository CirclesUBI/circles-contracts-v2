// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../errors/Errors.sol";
import "../hub/IHub.sol";
import "./IHub.sol";
import "./IToken.sol";

contract Migration is ICirclesErrors {
    // Constant

    uint256 private constant ACCURACY = uint256(10 ** 8);

    // State variables

    /**
     * @dev The address of the v1 hub contract.
     */
    IHubV1 public immutable hubV1;

    IHubV2 public hubV2;

    /**
     * @dev Deployment timestamp of Hub v1 contract
     */
    uint256 public immutable deployedAt;

    /**
     * @dev Inflationary period of Hub v1 contract
     */
    uint256 public immutable period;

    // Constructor

    constructor(IHubV1 _hubV1, IHubV2 _hubV2) {
        if (address(_hubV1) == address(0)) {
            // Hub v1 address can not be zero.
            revert CirclesAddressCannotBeZero(0);
        }
        if (address(_hubV2) == address(0)) {
            // Hub v2 address can not be zero.
            revert CirclesAddressCannotBeZero(1);
        }

        hubV1 = _hubV1;
        hubV2 = _hubV2;

        // from deployed v1 contract SHOULD return deployedAt = 1602786330
        // (for reference 6:25:30 pm UTC  |  Thursday, October 15, 2020)
        deployedAt = hubV1.deployedAt();
        // from deployed v1 contract SHOULD return period = 31556952
        // (equivalent to 365 days 5 hours 49 minutes 12 seconds)
        // because the period is not a whole number of hours,
        // the interval of hub v1 will not match the periodicity of any hour-based period in v2.
        period = hubV1.period();
    }

    // External functions

    /**
     * @notice Migrates the given amounts of v1 Circles to v2 Circles.
     * @param _avatars The avatars to migrate.
     * @param _amounts The amounts in inflationary v1 units to migrate.
     * @return convertedAmounts The converted amounts of v2 Circles.
     */
    function migrate(address[] calldata _avatars, uint256[] calldata _amounts) external returns (uint256[] memory) {
        if (_avatars.length != _amounts.length) {
            // Arrays length mismatch.
            revert CirclesArraysLengthMismatch(_avatars.length, _amounts.length, 0);
        }

        uint256[] memory convertedAmounts = new uint256[](_avatars.length);

        for (uint256 i = 0; i < _avatars.length; i++) {
            ITokenV1 circlesV1 = ITokenV1(hubV1.userToToken(_avatars[i]));
            if (address(circlesV1) == address(0)) {
                // Invalid avatar, not registered in hub V1.
                revert CirclesAddressCannotBeZero(2);
            }
            convertedAmounts[i] = convertFromV1ToDemurrage(_amounts[i]);
            // transfer the v1 Circles to this contract to be locked
            circlesV1.transferFrom(msg.sender, address(this), _amounts[i]);
        }

        // mint the converted amount of v2 Circles
        hubV2.migrate(msg.sender, _avatars, convertedAmounts);

        return convertedAmounts;
    }

    // Public functions

    /**
     * @notice Converts an amount of v1 Circles to demurrage Circles.
     * @param _amount The amount of v1 Circles to convert.
     */
    function convertFromV1ToDemurrage(uint256 _amount) public view returns (uint256) {
        // implement the linear interpolation that was used in V1 UI
        uint256 currentPeriod = hubV1.periods();
        uint256 nextPeriod = currentPeriod + 1;

        // calculate the start of the current period in unix time
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
        return (_amount * 3 * ACCURACY * period) / rP;
    }
}
