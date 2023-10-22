// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

/**
 * @title IHubv1
 * @author Circles UBI
 * @notice legacy interface of Hub contract in Circles v1
 */
interface IHubv1 {

    function signup() external;
    function organizationSignup() external;

    function tokenToUser(address token) external returns (address);
    function userToToken(address user) external returns (address);
    function limits(address truster, address trustee) external returns (uint256);

    function trust(address trustee, uint256 limit) external;
}