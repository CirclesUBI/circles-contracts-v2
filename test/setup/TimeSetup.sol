// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract TimeSetup is Test {
    // must match circles/TemporalDiscount.sol/ZERO_TIME
    uint256 internal constant ZERO_TIME = uint256(1639094400);

    function startTime() public {
        // Earliest sensib;e start time is ZERO_TIME plus one second
        vm.warp(ZERO_TIME + 1);
    }

    // vm.skip was not working, so just do it manually
    // todo: figure foundry test issues out with vm.skip
    function skipTime(uint256 _duration) public {
        uint256 afterSkip = block.timestamp + _duration;
        vm.warp(afterSkip);
    }
}
