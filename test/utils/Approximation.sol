// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

contract Approximation {
    function approximatelyEqual(uint256 a, uint256 b, uint256 epsilon) public pure returns (bool) {
        return a > b ? a - b <= epsilon : b - a <= epsilon;
    }
}
