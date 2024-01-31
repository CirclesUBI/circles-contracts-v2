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
     * Issue one token per time period (ie. one Circle per hour)
     * for a total of 24 tokens per 24 hours (~ per day).
     */
    uint256 public constant ISSUANCE_PERIOD = 1 hours;

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

    address public avatar;

    bool public stopped;

    /**
     * last issued stores the timestamp in seconds of when the last
     * tokens were issued to avatar. This must be combined with
     * the earliest timestamp received from the mint splitter upon minting.
     */
    uint256 public lastIssued;

    /**
     * last issuance time span stores the timespan in which those
     * latest issued tokens were issued, so that we can discount
     * newly issued tokens correctly.
     */
    uint256 public lastIssuanceTimeSpan;

    // Events

    event Stopped();

    // Modifiers

    modifier onlyGraph() {
        require(msg.sender == address(graph), "Only graph can call this function.");
        _;
    }

    modifier onlyAvatar() {
        require(msg.sender == avatar, "Only avatar can call this function.");
        _;
    }

    modifier notStopped() {
        require(!stopped, "Circle must not have been stopped.");
        _;
    }

    // Constructor

    constructor() TemporalDiscount() {}

    // External functions

    function setup(address _avatar) external {
        require(address(graph) == address(0), "Time Circle contract has already been setup.");

        require(address(_avatar) != address(0), "Avatar must not be zero address.");

        // graph contract must set up Time Circle node.
        graph = IGraph(msg.sender);
        avatar = _avatar;
        stopped = false;
        creationTime = block.timestamp;
        lastIssued = block.timestamp;
        lastIssuanceTimeSpan = _currentTimeSpan();
    }

    function entity() external view returns (address entity_) {
        return entity_ = avatar;
    }

    function claimIssuance() external notStopped {
        uint256 currentSpan = _currentTimeSpan();
        uint256 outstandingBalance = _calculateIssuance(currentSpan);
        require(outstandingBalance != uint256(0), "Minimally wait one hour between claims.");

        // mint the discounted balance for avatar
        _mint(avatar, outstandingBalance);
        lastIssuanceTimeSpan = currentSpan;
        lastIssued = block.timestamp;
    }

    /**
     * Path transfer is only accessible by the graph contract
     * to move circles along the flow graph induced from the balances
     * and trust relations.
     * Graph operators can also act as a core extension
     * over the authorized flow subgraph to access pathTransfer.
     */
    function pathTransfer(address _from, address _to, uint256 _amount) external onlyGraph {
        _transfer(_from, _to, _amount);
    }

    function stop() external onlyAvatar {
        if (!stopped) {
            emit Stopped();
        }
        stopped = true;
    }

    function calculateIssuance() external returns (uint256 outstandingBalance_) {
        if (stopped) {
            return uint256(0);
        }
        return _calculateIssuance(_currentTimeSpan());
    }

    function migrate(address _owner, uint256 _amount) external onlyGraph notStopped returns (uint256 migratedAmount_) {
        // simply mint the migration amount if the Circle is not stopped
        _mint(_owner, _amount);
        return migratedAmount_ = _amount;
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    // Internal functions

    /**
     * @dev Calculates the available issuance of tokens based on various factors such as allocation,
     *     timestamps, and discount windows.
     * @param _currentSpan The current time span for which the issuance is being calculated.
     * @return availableIssuance_ The amount of tokens that can be issued.
     *
     * The function starts by fetching the allocation and earliest timestamp from the graph contract.
     * It checks if the allocation is within the valid range and returns 0 if it's zero.
     * Next, it checks if the earliest timestamp is in the future, which would prevent the issuance of tokens.
     * If it is, it returns 0. Then, it determines the start time for issuance by taking the maximum value
     * between the earliest timestamp and the last issued timestamp.
     * The duration over which tokens can be claimed is calculated based on the maximum claim duration
     * and the time elapsed since the issuance start.
     * The function then calculates the full balance without discounting based on the duration claimable.
     * If the full balance without discounting is zero, it returns 0.
     * Next, it calculates the number of discount windows that have passed since the start of issuance.
     * If no discount windows have passed, it calculates the allocated outstanding balance
     * without applying any discounts.
     * If discount windows have passed, it applies the allocation to one circle per issuance period and
     * calculates the balance due for each discount window. It accumulates the available issuance by adding
     * the balance due for each window and applies the discount for each window transition.
     * Finally, it calculates the remaining time in the current discount window and adds the corresponding issuance amount.
     */
    function _calculateIssuance(uint256 _currentSpan) internal returns (uint256 availableIssuance_) {
        // ask the graph to fetch the allocation for issuance
        // and what the earliest timestamp is from which circles can be issued
        (int128 allocation, uint256 earliestTimestamp) = graph.fetchAllocation(avatar);

        require(allocation >= int128(0) && allocation <= ONE_64x64, "Allocation must be a between 0 and 1.");

        if (allocation == int128(0)) {
            // no allocation distributed towards this graph
            return availableIssuance_ = uint256(0);
        }

        uint256 presentTime = block.timestamp;

        // mint splitter can put earliest issuance time in the future
        // after updating the mint distribution
        if (earliestTimestamp >= presentTime) {
            // not allowed to issue circles if mint splitter set earliest time
            // in the future
            return availableIssuance_ = uint256(0);
        }

        // now that the earliest issuance time is in the past,
        // take the latest time as the start time
        uint256 issuanceStart = _max(earliestTimestamp, lastIssued);

        // the duration over which tokens can be claimed
        // is the duration since the start of a claim for a maximum
        // of two weeks.
        uint256 durationClaimable = _min(MAX_CLAIM_DURATION, presentTime - issuanceStart);

        // update the issuanceStart to account for maximum claim of two weeks.
        issuanceStart = presentTime - durationClaimable;

        // use integer division to round down towards the number
        // of completed issuance periods since last issued.
        uint256 fullBalanceWithoutDiscounting = (durationClaimable * EXA) / ISSUANCE_PERIOD;

        // don't bother discounting if oustanding balance is zero
        if (fullBalanceWithoutDiscounting == 0) {
            return availableIssuance_ = uint256(0);
        }

        uint256 startIssuanceTimeSpan = _calculateTimeSpan(issuanceStart);

        // the number of discounting windows that have passed.
        uint256 discountWindows = _currentSpan - startIssuanceTimeSpan;

        if (discountWindows == uint256(0)) {
            // within the same discount window, no discounts are applied
            // however, we must only mint the allocation distributed to this graph
            uint256 allocatedOutstandingBalance = Math64x64.mulu(allocation, fullBalanceWithoutDiscounting);
            return availableIssuance_ = allocatedOutstandingBalance;
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
        uint256 timeAccountedFor = issuanceStart;
        availableIssuance_ = uint256(0);
        for (uint256 i = startIssuanceTimeSpan; i < _currentSpan; i++) {
            uint256 endOfSpan = ZERO_TIME + (i + 1) * DISCOUNT_WINDOW;
            uint256 timeInSpan = endOfSpan - timeAccountedFor;
            // note: we want to have accuracy below one circle per hour,
            //       as a window transition is likely to fall within an hour.
            //       Luckily we can first multiply by ~10^18 (as timeInSpan < 10^6),
            //       which should be sufficiently accurate.
            //       (alternative is for using 64.64 fixed point math but consumes more gas)
            uint256 balanceDueForSpan = (circlesPerIssuancePeriod * timeInSpan) / ISSUANCE_PERIOD;
            availableIssuance_ += balanceDueForSpan;
            // transition the outstanding balance over a new discount window
            availableIssuance_ = _calculateDiscountedBalance(availableIssuance_, uint256(1));
            timeAccountedFor = endOfSpan;
        }
        timeAccountedFor = ZERO_TIME + _currentSpan * DISCOUNT_WINDOW;
        uint256 remainingTime = presentTime - timeAccountedFor;
        // don't discount in the current discount time window
        return availableIssuance_ += (circlesPerIssuancePeriod * remainingTime) / ISSUANCE_PERIOD;
    }

    // Private functions

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a <= b ? a : b;
    }

    function _max(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? a : b;
    }
}
