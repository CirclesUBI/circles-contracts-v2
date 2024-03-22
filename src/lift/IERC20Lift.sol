// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

enum CirclesType {
    Demurrage,
    Inflation
}

interface IERC20Lift {
    function ensureERC20(address avatar, CirclesType circlesType) external returns (address);
}
