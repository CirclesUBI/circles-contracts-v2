// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IToken v1
 * @author Circles UBI
 * @notice legacy interface of Hub contract in Circles v1
 */
interface ITokenV1 is IERC20 {
    function owner() external view returns (address);

    function stop() external;
    function stopped() external view returns (bool);

    function update() external;
}
