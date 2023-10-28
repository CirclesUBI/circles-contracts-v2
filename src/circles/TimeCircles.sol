// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../proxy/MasterCopyNonUpgradable.sol";
import "../graph/ICircleNode.sol";
import "../graph/IGraph.sol";

contract TimeCircle is MasterCopyNonUpgradable, ICircleNode {

    // Constants

    address public constant SENTINEL_MIGRATION = address(0x1);

    /** EXA factor as 10^18 */
    uint256 public constant EXA = uint256(1000000000000000000);

    /** Decimals of tokens are set to 18 */
    uint8 public constant DECIMALS = uint8(18);

    /** Store the signed 128-bit 64.64 representation of 1 as a constant */
    int128 public constant ONE_64x64 = int128(18446744073709551616);

    /** 
     * Reduction factor gamma for temporally discounting balances
     *   balance(t) = gamma^t * balance(t=0)
     * where 't' is expressed in units of DISCOUNT_RESOLUTION seconds,
     * and gamma is the reduction factor over that resolution period.
     * Gamma_64x64 stores the numerator for the signed 128bit 64.64
     * fixed decimal point expression:
     *   gamma = gamma_64x64 / 2**64.
     * Expressed in time[second], for 7% p.a. discounting:
     *   balance(t+1y) = (1 - 0.07) * balance(t)
     *   => gamma = (0.93)^(1/(365*24*3600))
     *            = 0.99999999769879842873...
     *   => gamma_64x64 = gamma * 2**64
     *                  = 18446744031260000000
     * If however, we express per unit of 1 week, 7% p.a.:
     *   => gamma = (0.93)^(1/52)
     *            = 0.998605383136377398...
     *   => gamma_64x64 = 18421018000000000000
    */
    int128 public constant GAMMA_64x64 = int128(18421018000000000000);

    /**
     * Discount resolution reduces the resolution for calculating
     * the discount of balances from one second (block.timestamp)
     * to one week time units.
     *   1 week = 7 * 24 * 3600 seconds = 604800 seconds
     */
    uint256 public constant DISCOUNT_RESOLUTION = uint256(604800);

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
        
        // loop over memory array to insert migration history into linked list
        for (uint256 i = 0; i < _migrations.length; i++) {
            insertMigration(_migrations[i]);
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