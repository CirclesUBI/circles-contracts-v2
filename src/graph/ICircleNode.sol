// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../circles/IERC20.sol";

/// @author CirclesUBI
/// @title Circle Node interface
interface ICircleNode is IERC20 {
    function setup(address avatar, bool active, address[] calldata migrations) external;

    function avatar() external view returns (address);

    function pathTransfer(address from, address to, uint256 amount) external;

    function paused() external view returns (bool paused);
    function stopped() external view returns (bool stopped);
    function isActive() external view returns (bool active);

    function pause() external;
    function unpause() external;
}
