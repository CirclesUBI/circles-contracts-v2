// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./TemporalDiscount.sol";
import "../proxy/MasterCopyNonUpgradable.sol";
import "../graph/ICircleNode.sol";
import "../graph/IGraph.sol";

contract TimeCircle is MasterCopyNonUpgradable, ICircleNode {

    // Constants

    address public constant SENTINEL_MIGRATION = address(0x1);

    /**
     * Issue one token per time period (ie. one token per hour)
     * for a total of 24 tokens per 24 hours (~ per day).
     */
    uint256 public constant ISSUANCE_PERIOD = 1 hours;

    /**
     * Signup bonus to allocate for new circle to node
     * if (to best efforts of estimation) this is a new signup.
     */
    uint256 public constant TIME_BONUS = 2 days / ISSUANCE_PERIOD;

    // State variables

    IGraph public graph;

    address public avatar;

    bool public active;

    mapping(address => address) public migrations;

    // External functions

    function setup(
        address _avatar,
        bool _active,
        address[] calldata _migrations
    )
        external
    {
        require(
            address(graph) == address(0),
            "Time Circle contract has already been setup."
        );

        require(
            address(_avatar) != address(0),
            "Avatar must not be zero address."
        );

        // graph contract must set up Time Circle node.
        graph = IGraph(msg.sender);
        avatar = _avatar;
        active =  _active;

        // instantiate the linked list
        // todo: this is not necessary with a prepend-linked list?
        // migrations[SENTINEL_MIGRATION] = SENTINEL_MIGRATION;
        
        // loop over memory array to insert migration history into linked list
        for (uint256 i = 0; i < _migrations.length; i++) {
            insertMigration(_migrations[i]);
        }

        // if the token has no known migration history and greenlit to start minting
        // then also allocate the initial "signup" bonus
        if (_migrations.length == 0 && _active) {
            // mint signup TIME_BONUS
        }
    }

    // Private function 
    
    function insertMigration(address _migration) private {
        require(
            _migration != address(0),
            "Migration address cannot be zero address."
        );
        // idempotent under repeated insertion
        if (migrations[_migration] != address(0)) {
            return;
        }
        // prepend new migration address at beginning of linked list
        migrations[_migration] = SENTINEL_MIGRATION;
        migrations[SENTINEL_MIGRATION] = _migration;
    }
}