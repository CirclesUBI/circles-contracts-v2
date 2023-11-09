// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/circles/TemporalDiscount.sol";

contract MockTimeCircles is TemporalDiscount {
    // State variables

    /**
     * address to which we mint new balances for testing
     */
    address public avatar;

    // Constructor
    constructor(address _avatar) {
        creationTime = block.timestamp;
        avatar = _avatar;
    }

    function mint(uint256 _balance) public {
        _mint(avatar, _balance);
    }

    function zeroTime() public pure returns (uint256 zeroTime_) {
        return ZERO_TIME;
    }
}
