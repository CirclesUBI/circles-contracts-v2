// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../circles/IERC20.sol";

/// @author CirclesUBI
/// @title Circle Node interface
interface ICircleNode is IERC20 {

    function entity() external view returns (address);

    function pathTransfer(address from, address to, uint256 amount) external;

    function isActive() external view returns (bool active);
}

interface IAvatarCircleNode is ICircleNode {

    function setup(address avatar, bool active, address[] calldata migrations) external;

    // function claimIssuance() external; 

    function paused() external view returns (bool paused);
    function stopped() external view returns (bool stopped);

    function pause() external;
    function unpause() external;
}

interface IGroupCircleNode is ICircleNode {
    function setup(address group) external;
}