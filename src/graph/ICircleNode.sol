// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

/// @author CirclesUBI
/// @title Circle Node interface
interface ICircleNode {
    function setup(address avatar, bool active, address[] calldata migrations) external;

    function avatar() external view returns (address);

    function paused() external view returns (bool paused);
    function stopped() external view returns (bool stopped);
    function isActive() external view returns (bool active);

    function pause() external;
    function unpause() external;
}
