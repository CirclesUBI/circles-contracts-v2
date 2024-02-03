// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @author CirclesUBI
/// @title Circle Node interface
interface ICircleNode is IERC20 {
    function entity() external view returns (address);

    function pathTransfer(address from, address to, uint256 amount) external;

    function burn(uint256 amount) external;
}

interface IAvatarCircleNode is ICircleNode {
    function setup(address avatar) external;

    function stopped() external view returns (bool stopped);

    // only personal Circles from v1 can be migrated, as group circles were not native in v1
    function migrate(address owner, uint256 amount) external returns (uint256 migratedAmount);
}

interface IGroupCircleNode is ICircleNode {
    function setup(address group, int128 exitFee_64x64) external;
}
