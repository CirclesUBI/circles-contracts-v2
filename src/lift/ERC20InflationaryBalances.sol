// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../circles/Demurrage.sol";
import "./ERC20Permit.sol";

abstract contract ERC20InflationaryBalances is ERC20Permit, Demurrage, IERC20 {
// Constants

// State variables
}
