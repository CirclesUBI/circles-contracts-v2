// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IHubV2 {
    function avatars(address avatar) external view returns (address);
    function migrate(address owner, address[] calldata avatars, uint256[] calldata amounts) external;
}
