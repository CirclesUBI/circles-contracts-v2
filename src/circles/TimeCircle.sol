// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./TemporalDiscount.sol";
import "../proxy/MasterCopyNonUpgradable.sol";
import "../graph/ICircleNode.sol";
import "../graph/IGraph.sol";

contract TimeCircle is MasterCopyNonUpgradable, TemporalDiscount, IAvatarCircleNode {
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

    /**
     * Per call to claim issuance, the maximum amount of tokens
     * that can be claimed only goes back 2 weeks in time.
     */
    uint256 public constant MAX_ISSUANCE = MAX_CLAIM_DURATION / ISSUANCE_PERIOD;

    uint256 public constant MAX_CLAIM_DURATION = 2 weeks;

    /**
     * compute the number of issuance periods per discount window:
     *   1 week / 1 hour = 7 * 24 = 168
     * note: before issuance these tokens still need to discounted
     *       per discount window.
     */
    uint256 internal constant PERIODS_PER_DISCOUNT = DISCOUNT_WINDOW / ISSUANCE_PERIOD;

    // State variables

    IGraph public graph;

    address public avatar;

    bool public paused;

    bool public stopped;

    /**
     * last issued stores the timestamp in seconds of when the last
     * tokens were issued to avatar.
     */
    uint256 public lastIssued;

    /**
     * last issuance time span stores the timespan in which those
     * latest issued tokens were issued, so that we can discount
     * newly issued tokens correctly.
     */
    uint256 public lastIssuanceTimeSpan;

    mapping(address => address) public migrations;

    // Events

    event Paused(address indexed caller);

    // Modifiers

    modifier onlyGraphOrAvatar() {
        require(msg.sender == address(graph) || msg.sender == avatar, "Only graph or avatar can call this function.");
        _;
    }

    modifier onlyGraph() {
        require(msg.sender == address(graph), "Only graph can call this function.");
        _;
    }

    modifier onlyActive() {
        require(isActive(), "Node must be active to call this function.");
        _;
    }

    modifier notStopped() {
        require(!stopped, "Node must not have been stopped.");
        _;
    }

    constructor() {
        // block the mastercopy from getting called setup on
        graph = IGraph(address(1));
    }

    // External functions

    function setup(address _avatar) external {
        require(address(graph) == address(0), "Time Circle contract has already been setup.");

        require(address(_avatar) != address(0), "Avatar must not be zero address.");

        // graph contract must set up Time Circle node.
        graph = IGraph(msg.sender);
        avatar = _avatar;
        // paused = !_active;
        stopped = false;
        creationTime = block.timestamp;
        lastIssued = block.timestamp;
        lastIssuanceTimeSpan = _currentTimeSpan();

        // instantiate the linked list
        // migrations[SENTINEL_MIGRATION] = SENTINEL_MIGRATION;

        // // loop over memory array to insert migration history into linked list
        // for (uint256 i = 0; i < _migrations.length; i++) {
        //     _insertMigration(_migrations[i]);
        // }

        // if the token has no known migration history and greenlit to start minting
        // then also allocate the initial "signup" bonus
        // if (_migrations.length == 0 && _active) {
        //     // mint signup TIME_BONUS
        //     // for bonus don't discount the tokens per hour,
        //     // simply give the full amount as it is a rounded amount,
        //     // and clearer to understand for new users.
        //     _mint(avatar, TIME_BONUS * EXA);
        // }
    }

    function entity() external view returns (address entity_) {
        return entity_ = avatar;
    }

    function claimIssuance() external onlyActive {
        uint256 currentSpan = _currentTimeSpan();
        uint256 outstandingBalance = _calculateIssuance(currentSpan);
        require(outstandingBalance == uint256(0), "Minimally wait one hour between claims.");

        // mint the discounted balance for avatar
        _mint(avatar, outstandingBalance);
        lastIssuanceTimeSpan = currentSpan;
        lastIssued = block.timestamp;
    }

    function pathTransfer(address _from, address _to, uint256 _amount) external onlyGraph {
        _transfer(_from, _to, _amount);
    }

    // function pause() external onlyGraphOrAvatar notStopped {
    //     // pause can be quitely idempotent
    //     if (!paused) {
    //         paused = true;
    //         emit Paused(msg.sender);
    //     }
    // }

    // function unpause() external onlyGraph notStopped {
    //     require(paused, "Node must be explicitly paused, to unpause.");
    //     // explicitly reset last issuance time to now to set a fresh clock,
    //     // but without issuing tokens for the paused time.
    //     lastIssuanceTimeSpan = _currentTimeSpan();
    //     lastIssued = block.timestamp;
    //     paused = false;

    //     // todo: emit event
    // }

    // todo: function stop()

    function calculateIssuance() external onlyActive returns (uint256 outstandingBalance_) {
        return _calculateIssuance(_currentTimeSpan());
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    // Public functions

    function isActive() public view returns (bool active_) {
        return !paused && !stopped;
    }

    // Internal functions

    function _calculateIssuance(uint256 _currentSpan) internal returns (uint256 outstandingBalance_) {
        // ask the graph to fetch the allocation for issuance and what the earliest timestamp is
        // from which circles can be issued
        (int128 allocation, uint256 earliestTimestamp) = graph.fetchAllocation();

        require(allocation >= int128(0) && allocation <= ONE_64x64, "Allocation must be a between 0 and 1.");

        uint256 presentTime = block.timestamp;

        if (allocation == int128(0)) {
            // no allocation distributed towards this graph
            return outstandingBalance_ = uint256(0);
        }

        // mint splitter can put earliest issuance time in the future
        // after updating the mint distribution
        if (earliestTimestamp >= presentTime) {
            // not allowed to issue circles if mint splitter set earliest time
            // in the future
            return outstandingBalance_ = uint256(0);
        }

        // now that the earliest issuance time is in the past,
        // take the latest time as the start time
        uint256 issuanceStart = _max(earliestTimestamp, lastIssued);

        // the duration over which tokens can be claimed
        // is the duration since the start of a claim for a maximum
        // of two weeks.
        uint256 durationClaimable = _min(MAX_CLAIM_DURATION, presentTime - issuanceStart);

        // use integer division to round down towards the number
        // of completed issuance periods since last issued.
        uint256 fullBalanceWithoutDiscounting = durationClaimable / ISSUANCE_PERIOD;

        // don't bother discounting if oustanding balance is zero
        if (fullBalanceWithoutDiscounting == 0) {
            return outstandingBalance_ = uint256(0);
        }

        // the number of discounting windows that have passed.
        uint256 discountWindows = _currentSpan - lastIssuanceTimeSpan;

        if (discountWindows == uint256(0)) {
            // within the same discount window, no discounts are applied
            // however, we must only mint the allocation distributed to this graph
            uint256 allocatedOutstandingBalance = Math64x64.mulu(allocation, fullBalanceWithoutDiscounting);
            return outstandingBalance_ = allocatedOutstandingBalance;
        }

        // apply the allocation to one circle (10**18 = EXA) per period (1 hour)
        uint256 circlesPerIssuancePeriod = Math64x64.mulu(allocation, EXA);

        // note: because the maximal claim duration is only a few discount windows
        //       the start and end span are the majority of cases and covered better by
        //       a naive loop; for different parameters, this loop could be longer
        //       and an explicit geometric sum for the repetitive windows in the middle
        //       would make more sense.
        // todo: the discount window will be updated from 1 week to 1 day (or less),
        //       so consider whether this is still the most optimal implementation.
        //       follow-up on https://github.com/CirclesUBI/circles-contracts-v2/issues/25
        uint256 timeAccountedFor = presentTime - durationClaimable;
        outstandingBalance_ = uint256(0);
        for (uint256 i = lastIssuanceTimeSpan; i < _currentSpan; i++) {
            uint256 endOfWindow = ZERO_TIME + (i + 1) * DISCOUNT_WINDOW;
            uint256 timeInWindow = endOfWindow - timeAccountedFor;
            // note: we want to have accuracy below one circle per hour,
            //       as a window transition is likely to fall within an hour.
            //       Luckily we can first multiply by ~10^18 (as timeInWindow < 10^6),
            //       which should be sufficiently accurate.
            //       (alternative is for using 64.64 fixed point math but consumes more gas)
            uint256 balanceDueForWindow = (circlesPerIssuancePeriod * timeInWindow) / ISSUANCE_PERIOD;
            outstandingBalance_ += balanceDueForWindow;
            // transition the outstanding balance over a new discount window
            outstandingBalance_ = _calculateDiscountedBalance(outstandingBalance_, uint256(1));
            timeAccountedFor = endOfWindow;
        }
        timeAccountedFor = ZERO_TIME + _currentSpan * DISCOUNT_WINDOW;
        uint256 remainingTime = presentTime - timeAccountedFor;
        // don't discount in the current discount time window
        return outstandingBalance_ += (circlesPerIssuancePeriod * remainingTime) / ISSUANCE_PERIOD;
    }

    // Private function

    // function _insertMigration(address _migration) private {
    //     assert(_migration != SENTINEL_MIGRATION);
    //     require(_migration != address(0), "Migration address cannot be zero address.");
    //     // idempotent under repeated insertion
    //     if (migrations[_migration] != address(0)) {
    //         return;
    //     }
    //     // prepend new migration address at beginning of linked list
    //     migrations[_migration] = migrations[SENTINEL_MIGRATION];
    //     migrations[SENTINEL_MIGRATION] = _migration;
    // }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a <= b ? a : b;
    }

    function _max(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? a : b;
    }
}
