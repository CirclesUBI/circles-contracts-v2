// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../lib/Math64x64.sol";

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 balance);
    function transfer(address to, uint256 value) external returns (bool success);
    function transferFrom(address from, address to, uint256 value) external returns (bool success);
    function approve(address spender, uint256 value) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256 remaining);
}

abstract contract TemporalDiscount is IERC20 {

    // Constants

    /** Decimals of tokens are set to 18 */
    uint8 public constant DECIMALS = uint8(18);

    /**
     * Discount resolution reduces the resolution for calculating
     * the discount of balances from one second (block.timestamp)
     * to one week time units.
     *   1 week = 7 * 24 * 3600 seconds = 604800 seconds = 1 weeks
     */
    uint256 public constant DISCOUNT_RESOLUTION = 1 weeks;

    /** EXA factor as 10^18 */
    uint256 private constant EXA = uint256(1000000000000000000);

    /** Store the signed 128-bit 64.64 representation of 1 as a constant */
    int128 private constant ONE_64x64 = int128(18446744073709551616);

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
    int128 private constant GAMMA_64x64 = int128(18421018000000000000);

    /** Arbitrary origin for counting time since 10 December 2021
     *  "Hope" is the thing with feathers -
     */
    uint256 private constant ZERO_TIME = uint256(1639094400);

    // State variables

    /** Creation time stores the time this time circle node was created */
    // note: this is not strictly needed, can remove later if we want to optimise
    uint256 public creationTime;

    /** Temporal total supply stores the total supply at the time it was last updated. */
    uint256 private temporalTotalSupply;

    /** Total supply time stores the time at which total supply was last written to. */
    uint256 private totalSupplyTime;

    /**
     * Temporal balances store the amount of tokens an address
     * has, understood as in a certain time span,
     * ie. when the balance was last updated.
     * Use balanceOf() to compute the current, discounted balance.
     */
    mapping(address => uint256) public temporalBalances;

    /**
     * Balance time spans stores the time span in which 
     * temporalBalances was written to.
     */
    mapping(address => uint256) public balanceTimeSpans;

    // Events

    event Transfer(address indexed from, address indexed to, uint256 amount);

    /**
     * @notice DiscountCost is emitted when the owner sends or receives tokens
     *         in a new time span and emits the discounted amount
     *         computed over the balance before sending or receiving the new amount.
     * @param owner owner of the balance for which a temporal discount cost was applied.
     * @param cost the amount that has been deducted from the balance for temporal discounting.
     */
    event DiscountCost(address indexed owner, uint256 cost);

    // External functions

    function totalSupply() external view returns(uint256 totalSupply_) {

    }

    /**
     * @notice balanceOf returns the balance of owner discounted
     *         up to current time span.
     * @param _owner owns a temporally discounted balance of tokens.
     */
    function balanceOf(address _owner) external view returns (uint256 balance_) {
        uint256 currentSpan = currentTimeSpan();
        if (balanceTimeSpans[_owner] == currentSpan) {
            // within the same time span balances are constant
            return balance_ = temporalBalances[_owner];
        } else {
            // preserve the expectation balanceOf as a view function
            // and don't store the computed result on read operations.
            return balance_ = calculateDiscountedBalance(
                temporalBalances[_owner],
                currentSpan - balanceTimeSpans[_owner]
            );
        }
    }

    function transfer(address to, uint256 value) external returns (bool success) {

    }

    // Internal functions

    /**
     * @notice current time span returns the count of time spans (counted in weeks)
     *         that have passed since ZERO_TIME.
     */
    function currentTimeSpan() internal view returns (uint256 currentTimeSpan_) {
        // integer division rounds down, a difference less than one week
        // is counted as zero (since ZERO_TIME, or when making)
        return
            ((block.timestamp - ZERO_TIME) / DISCOUNT_RESOLUTION);
    }

    // Private functions

    function discountBalanceThenAdd(
        address _owner,
        uint256 _amount,
        uint256 _currentSpan
    ) private returns (uint256 discountedBalance_) {
        // todo: continue here
        if (balanceTimeSpans[_owner] == _currentSpan) {
            // within the same time span balances are constant, noop
            return discountedBalance_ = temporalBalances[_owner];
        } else {
            // 
            return calculateDiscountedBalance(
                temporalBalances[_owner],
                _currentSpan - balanceTimeSpans[_owner]
            );
        }       
    }

    function calculateDiscountedBalance(
        uint256 _balance,
        uint256 _numberOfTimeSpans
    ) private pure returns (uint256 discountedBalance_) {
        // exponentiate the reduction factor by the number of time spans (of one week)
        // todo: as most often the number of time spans would be a low integer
        //       we can cache a table of the initial reduction factors.
        //       evaluate how much gas this would save;
        //       alternatively a cache table could be dynamically built.
        int128 reduction64x64 = Math64x64.pow(GAMMA_64x64, _numberOfTimeSpans);
        // return the discounted the balance
        discountedBalance_ = Math64x64.mulu(reduction64x64, _balance);
    }
}