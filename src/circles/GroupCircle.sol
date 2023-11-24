// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./TemporalDiscount.sol";
import "../proxy/MasterCopyNonUpgradable.sol";
import "../graph/ICircleNode.sol";
import "../graph/IGraph.sol";
import "./IGroup.sol";

contract GroupCircle is MasterCopyNonUpgradable, TemporalDiscount, IGroupCircleNode {
    // State variables

    IGraph public graph;

    // todo: we probably want group to have an interface so that we can call hooks on it
    IGroup public group;

    /**
     * The exit fee (represented as 128bit 64.64 fixed point) is charged upon
     * unwrapping the group circles back to the collateral personal circles.
     * Note that one can only unwrap group circles for the amount of personal
     * circles that are collateralized in the group, ie. the minimum of the amount
     * of group circles you want to unwrap, and the amount of your personal
     * circles that are collateralized in this group.
     * If the the exit fee is set to the maximum of 100% (= 2**64 in 64.64),
     * then upon minting the collateral is immediately burnt instead.
     */
    int128 public exitFee_64x64;

    /**
     * Burn collateral upon minting is set to true,
     * if the exit fee was set to 100%.
     */
    bool public burnCollateralUponMinting;

    // Modifiers

    modifier onlyGraphOrGroup() {
        require(
            msg.sender == address(graph) || msg.sender == address(group), "Only graph or group can call this function."
        );
        _;
    }

    modifier onlyGraph() {
        require(msg.sender == address(graph), "Only graph can call this function.");
        _;
    }

    // External functions

    function setup(address _group, int128 _exitFee_64x64) external {
        require(address(graph) == address(0), "Group circle contract has already been setup.");

        require(address(_group) != address(0), "Group address must not be zero address");

        require(_exitFee_64x64 <= ONE_64x64, "Exit fee can maximally be 100%.");

        if (_exitFee_64x64 == ONE_64x64) {
            burnCollateralUponMinting = true;
        } else {
            burnCollateralUponMinting = false;
        }

        // graph contract must call setup after deploying proxy contract
        graph = IGraph(msg.sender);
        group = IGroup(_group);
        creationTime = block.timestamp;
        exitFee_64x64 = _exitFee_64x64;
    }

    function entity() external view returns (address entity_) {
        return entity_ = address(group);
    }

    function pathTransfer(address _from, address _to, uint256 _amount) external onlyGraph {
        // todo: should there be a hook here to call group?

        _transfer(_from, _to, _amount);
    }

    // todo: does this mean something for group currencies?
    function isActive() external pure returns (bool active_) {
        return active_ = true;
    }

    function mint(ICircleNode[] calldata _collateral, uint256[] calldata _amount) external {
        require(_collateral.length == _amount.length, "Collateral and amount arrays must have equal length.");

        require(_collateral.length > 0, "At least one collateral must be provided.");

        // note: this is for code readability, this gets compiled out.
        // To compose group tokens as deposited collateral must be burnt.
        // For example, if collateral is preserved one could redeposit
        // (the same) group tokens, and the collateral would accumulate on
        // what should be an idempotent function call.
        // This prevents games to be played with inflated total collateral held by groups.
        bool acceptGroupTokensAsCollateral = burnCollateralUponMinting;

        require(
            graph.checkAllAreValidCircleNodes(_collateral, acceptGroupTokensAsCollateral),
            "All collateral must be valid circles on this graph."
        );

        // rely on group logic to evaluate whether minting should proceed
        group.beforeMintPolicy(msg.sender, _collateral, _amount);

        uint256 totalGroupCirclesToMint = uint256(0);

        for (uint256 i = 0; i < _collateral.length; i++) {
            _collateral[i].transferFrom(msg.sender, address(this), _amount[i]);
            totalGroupCirclesToMint += _amount[i];
        }

        _mint(msg.sender, totalGroupCirclesToMint);

        if (burnCollateralUponMinting) {
            for (uint256 i = 0; i < _collateral.length; i++) {
                _collateral[i].burn(_amount[i]);
            }
        }
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
