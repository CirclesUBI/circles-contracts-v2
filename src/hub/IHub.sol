// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IHubV2 {
    function avatars(address _avatar) external view returns (address);
    function mintPolicies(address _avatar) external view returns (address);
}
