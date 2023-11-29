// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./IMintSplitter.sol";
import "../migration/IHub.sol";
import "../migration/IToken.sol";
import "../lib/Math64x64.sol";

contract MintSplitter is IMintSplitter {
    // Type declarations

    struct Distribution {
        int128 allocation;
        uint128 sequence; // pack into the first word
        address destinationIterator;
    }

    enum HubV1Lock {
        Undetermined,
        LockedToHubV1,
        LockReleased
    }

    // Constants

    address public constant SENTINEL = address(1);

    int128 public constant ONE_64x64 = int128(2 ** 64);

    /**
     * @notice UPDATE_RELAXATION_TIME_FEE is the minimum time before
     *     one can update their distribution again.
     *     This effectively introduces a fee for updating
     *     of one minute, because any mint only counts
     *     from after the (update + relaxation) time.
     */
    uint256 public constant UPDATE_RELAXATION_TIME_FEE = 1 minutes;

    /**
     * @notice there is no intention for splitting your mint
     *     into many destinations, so putting an arbitrary cap
     *     to set expectations for usage.
     */
    uint8 public constant MAX_DISTRIBUTIONS = uint8(7);

    // State variables

    /**
     * @notice Hub v1 contract needs to be explicitly handled
     *     for compatibility of the original code with new hubs
     */
    IHubV1 public immutable hubV1;

    /**
     * @notice sources stores a linked list of all
     *     the sources that have declared minting destinations.
     */
    mapping(address => address) public sources;

    /**
     * @notice destinations stores a linked list of all
     *     the mint destinations that have been recorded.
     */
    mapping(address => address) public destinations;

    /**
     * @notice last updated distribution stores the timestamp
     *     when last the source called to update their distribution.
     *     All destinations MUST only mint their allocation from
     *     last updated timestamp to present.
     */
    mapping(address => uint256) public lastUpdatedDistribution;

    mapping(address => mapping(address => Distribution)) public distributions;

    mapping(address => uint128) public sourceSequences;

    mapping(address => HubV1Lock) public hubV1Locks;

    // Modifiers

    modifier canUpdate(address _source) {
        require(
            lastUpdatedDistribution[_source] < block.timestamp, "Source can not update twice at the same block time."
        );
        // first update the lock for the source
        checkSourceLockHubV1(_source);
        require(hubV1Locks[_source] != HubV1Lock.LockedToHubV1, "Source has the distribution locked to hub v1 minting.");
        _;
    }

    // Constructor

    constructor(IHubV1 _hubV1) {
        require(address(_hubV1) != address(0), "Hub v1 contract must be provided.");

        hubV1 = _hubV1;

        // initialize the linked lists
        sources[SENTINEL] = SENTINEL;
        destinations[SENTINEL] = SENTINEL;
    }

    // External functions

    function registerDistribution(address[] calldata _destinations, int128[] calldata _allocations)
        external
        canUpdate(msg.sender)
    {
        require(_destinations.length <= MAX_DISTRIBUTIONS, "Maximum number of split destinations is 7.");
        require(_destinations.length > 0, "Cannot register empty distribution.");
        require(_destinations.length == _allocations.length, "Each destination must have an allocation");

        require(
            addsToOneUnit(_allocations), "Provided allocations must add to one in 64.64 bit fixed point representation."
        );

        // register the source
        _insertSource(msg.sender);

        // register the destinations, also checks destinations are not zero.
        for (uint256 i = 0; i < _destinations.length - 1; i++) {
            require(
                uint160(_destinations[i]) < uint160(_destinations[i + 1]),
                "Destinations must be unique and provided in ascending order."
            );
            _insertDestination(_destinations[i]);
        }
        _insertDestination(_destinations[_destinations.length - 1]);

        // add an additional relaxation time fee for updating the distribution
        lastUpdatedDistribution[msg.sender] = block.timestamp + UPDATE_RELAXATION_TIME_FEE;

        // delete all distributions for the source and initialize a new one
        uint128 newSequence = _deleteDistributionAndInitializeNew(msg.sender);
        // because the construction is involved, track a sanity check independently
        // in the form of a sequence number
        assert(newSequence == sourceSequences[msg.sender] + 1);
        sourceSequences[msg.sender] = newSequence;

        // store the new distribution
        _storeNewDistribution(msg.sender, newSequence, _destinations, _allocations);
    }

    function allocationTowardsCaller(address _source)
        external
        returns (int128 allocation_, uint256 earliestTimestamp_)
    {
        require(destinations[msg.sender] != address(0), "Destination has not been registered before.");
        require(sources[_source] != address(0), "Source has not registered a distribution.");

        HubV1Lock sourceLockStatus = checkSourceLockHubV1(_source);

        require(sourceLockStatus != HubV1Lock.LockedToHubV1, "Mint is exclusively locked to Hub V1 token.");

        Distribution storage distribution = distributions[_source][msg.sender];
        require(
            distribution.destinationIterator != address(0), "No distribution has been allocated for this destination."
        );
        assert(distribution.sequence == sourceSequences[_source]);
        assert(distribution.allocation >= int128(0) && distribution.allocation <= ONE_64x64);

        return (allocation_ = distribution.allocation, earliestTimestamp_ = lastUpdatedDistribution[_source]);
    }

    // Public functions

    function checkSourceLockHubV1(address _source) public returns (HubV1Lock lockStatus_) {
        lockStatus_ = hubV1Locks[_source];
        if (lockStatus_ == HubV1Lock.LockReleased) {
            // once the lock is released, this is the final state
            // so immediately continue
            return lockStatus_;
        }

        address hubV1Token = hubV1.userToToken(_source);
        if (hubV1Token != address(0)) {
            // some address is returned
            bool stopped = ITokenV1(hubV1Token).stopped();
            if (stopped) {
                // the existing v1 token has been stopped, so the lock can be released
                lockStatus_ = HubV1Lock.LockReleased;
                // ensure that there are no overlapping mints, so update the timestamp
                // for new distributions
                lastUpdatedDistribution[_source] = block.timestamp;
            } else {
                assert(lockStatus_ <= HubV1Lock.LockedToHubV1);
                // the existing v1 token is (still) present and not stopped, so place the lock
                lockStatus_ = HubV1Lock.LockedToHubV1;
            }
        } else {
            // no address was returned, no v1 token exists
            assert(lockStatus_ == HubV1Lock.Undetermined);
            // no-op, lock status remains undetermined, as source can signup
            // in Hub V1 contract and start a mint there
            return lockStatus_;
        }
        // store the updated lock status
        hubV1Locks[_source] = lockStatus_;
        return lockStatus_;
    }

    function addsToOneUnit(int128[] calldata _allocations) public pure returns (bool unitary_) {
        int128 sum = int128(0);

        for (uint256 i = 0; i < _allocations.length; i++) {
            require(
                _allocations[i] >= int128(0) && _allocations[i] <= ONE_64x64,
                "Any allocation must be between zero and one."
            );
            // note: with high confidence we can simply add the int128 numbers
            //     because we already constrain them between zero and one ...
            //     but to be extra cautious use a range check on each addition
            sum = Math64x64.add(sum, _allocations[i]);
        }
        require(sum <= ONE_64x64, "Sum exceeded one unit.");
        // return true if the sum of all allocations adds up to one.
        return (sum == ONE_64x64);
    }

    // Private functions

    function _insertSource(address _source) private {
        assert(_source != address(0));
        assert(_source != SENTINEL);

        if (sources[_source] != address(0)) {
            // insertion is idempotent
            return;
        }

        // insert new source in linked list
        sources[_source] = sources[SENTINEL];
        sources[SENTINEL] = _source;
    }

    function _insertDestination(address _destination) private {
        require(_destination != address(0), "Destination cannot be zero.");
        require(_destination != SENTINEL, "Destination cannot be address 0x1.");

        if (destinations[_destination] != address(0)) {
            // insert is idempotent
            return;
        }

        // insert new source in linked list
        destinations[_destination] = destinations[SENTINEL];
        destinations[SENTINEL] = _destination;
    }

    function _storeNewDistribution(
        address _source,
        uint128 _sequence,
        address[] calldata _destinations,
        int128[] calldata _allocations
    ) private {
        // assume lengths of arrays are already checked to be equal and > 0
        // and values are valid

        Distribution storage sentinelDistribution = distributions[_source][SENTINEL];
        require(
            sentinelDistribution.destinationIterator == SENTINEL,
            "Distribution must be empty and initialized before storing new."
        );
        uint128 sequence = sentinelDistribution.sequence;
        require(sequence == _sequence, "Sequence number provided does not match initialized, empty distribution.");
        address previousIterator = SENTINEL;
        for (uint256 i = 0; i < _destinations.length; i++) {
            Distribution storage distribution = distributions[_source][_destinations[i]];
            distribution.allocation = _allocations[i];
            distribution.sequence = sequence;
            distribution.destinationIterator = previousIterator;
            previousIterator = _destinations[i];
        }
        sentinelDistribution.allocation = int128(0);
        sentinelDistribution.destinationIterator = previousIterator;
    }

    function _deleteDistributionAndInitializeNew(address _source) private returns (uint128 sequence_) {
        Distribution storage sentinelDistribution = distributions[_source][SENTINEL];
        if (sentinelDistribution.destinationIterator == address(0)) {
            // distribution is uninitialized, so initialize
            sentinelDistribution.allocation = int128(0);
            sentinelDistribution.sequence = uint128(1);
            sentinelDistribution.destinationIterator = SENTINEL;
            return sequence_ = uint128(1);
        } else if (sentinelDistribution.destinationIterator == SENTINEL) {
            // distribution is initialised, and list is empty
            return sequence_ = sentinelDistribution.sequence;
        }

        // handle delete by iterating over all stored distributions,
        // deleting them one by one and resetting the sentinel.
        // we opt to perform O(N) operations for updating the distribution
        // so that we can retrieve distribution allocations in O(1) time
        // with the mapping.
        uint8 count = 0;
        uint128 sequence = sentinelDistribution.sequence;
        address nextDestination = sentinelDistribution.destinationIterator;
        while (nextDestination != SENTINEL) {
            Distribution storage distribution = distributions[_source][nextDestination];
            assert(distribution.sequence == sequence);
            nextDestination = distribution.destinationIterator;
            delete distribution.allocation;
            delete distribution.sequence;
            delete distribution.destinationIterator;
            count++;
            assert(count <= MAX_DISTRIBUTIONS);
        }
        // reset the sentinel distribution
        sentinelDistribution.allocation = int128(0);
        sentinelDistribution.sequence = uint128(sequence + 1);
        sentinelDistribution.destinationIterator = SENTINEL;
        return sequence_ = sentinelDistribution.sequence;
    }
}
