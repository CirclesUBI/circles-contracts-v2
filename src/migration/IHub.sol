// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

/**
 * @title IHub v1
 * @author Circles
 * @notice legacy interface of Hub contract in Circles v1
 */
interface IHubV1 {
    function signup() external;
    function signupBonus() external view returns (uint256);
    function organizationSignup() external;
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);

    function tokenToUser(address token) external view returns (address);
    function userToToken(address user) external view returns (address);
    function limits(address truster, address trustee) external returns (uint256);

    function trust(address trustee, uint256 limit) external;

    function deployedAt() external view returns (uint256);
    function initialIssuance() external view returns (uint256);
    function issuance() external view returns (uint256);
    function issuanceByStep(uint256 periods) external view returns (uint256);
    function inflate(uint256 initial, uint256 periods) external view returns (uint256);
    function inflation() external view returns (uint256);
    function divisor() external view returns (uint256);
    function period() external view returns (uint256);
    function periods() external view returns (uint256);
    function timeout() external view returns (uint256);
}
