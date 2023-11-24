// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./TemporalDiscount.sol";
import "../proxy/MasterCopyNonUpgradable.sol";
import "../graph/ICircleNode.sol";
import "../graph/IGraph.sol";


/**
 * Upon minting group tokens, are the underlying circles
 * to be locked for later redemption, or instead burned.
 * Redemption only allows you to recover your personal circles,
 * for however many of your personal circles are available in the group.
 * (todo: this is one redemption strategy, up for later discussion)
 */
enum MintBehaviour {
    Lock,
    Burn
}

contract GroupCircle is MasterCopyNonUpgradable, TemporalDiscount, IGroupCircleNode {

    // State variables

    IGraph public graph;

    // todo: we probably want group to have an interface so that we can call hooks on it
    address public group;

    MintBehaviour public mintBehaviour;

    // Modifiers

    modifier onlyGraphOrGroup() {
        require(
            msg.sender == address(graph) || msg.sender == group,
            "Only graph or group can call this function."
        );
        _;
    }

    modifier onlyGraph() {
        require(
            msg.sender == address(graph),
            "Only graph can call this function."
        );
        _;
    }

    // External functions

    function setup(address _group, ) external {
        require(
            address(graph) == address(0),
            "Group circle contract has already been setup."
        );

        require(
            address(_group) != address(0),
            "Group address must not be zero address"
        );
        
        // graph contract must call setup after deploying proxy contract
        graph = IGraph(msg.sender);
        group = _group;
        creationTime = block.timestamp;
    }

    function entity() external view returns (address entity_) {
        return entity_ = group;
    }

    function pathTransfer(address _from, address _to, uint256 _amount) external onlyGraph {

        // todo: should there be a hook here to call group?

        _transfer(_from, _to, _amount);
    }

    // todo: does this mean something for group currencies?
    function isActive() external pure returns (bool active_) {
        return active_ = true;
    }

    // function mint();

}