// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/circles/Circles.sol";

contract MockCircles is Circles {
    // State variables

    // Constructor
    constructor(uint256 _demurrageBase) Circles(_demurrageBase, "") {}

    // External functions

    function registerHuman(address _human) external {
        mintTimes[_human].lastMintTime = uint96(block.timestamp);
    }

    function registerHumans(address[] calldata _humans) external {
        for (uint256 i = 0; i < _humans.length; i++) {
            mintTimes[_humans[i]].lastMintTime = uint96(block.timestamp);
        }
    }

    function calculateIssuance(address _human) external returns (uint256) {
        return _calculateIssuance(_human);
    }

    function claimIssuance() external {
        require(mintTimes[msg.sender].lastMintTime != 0, "Circles: Not registered");
        _claimIssuance(msg.sender);
    }
}
