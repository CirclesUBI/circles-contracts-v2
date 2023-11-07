// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

/**
 * @title IToken v1
 * @author Circles UBI
 * @notice legacy interface of Hub contract in Circles v1
 */
interface ITokenV1 {
    function owner() external view returns (address);

    function stopped() external view returns (bool);
}
