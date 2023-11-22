// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./TemporalDiscount.sol";
import "../proxy/MasterCopyNonUpgradable.sol";
import "../graph/ICircleNode.sol";
import "../graph/IGraph.sol";

contract GroupCircle is MasterCopyNonUpgradable, TemporalDiscount, IGroupCircleNode {

    function setup(address _group) external {

    }

    function entity() external view returns (address) {

    }

    function pathTransfer(address from, address to, uint256 amount) external {

    }

    function isActive() external pure returns (bool active_) {

        return active_ = true;
    }

}