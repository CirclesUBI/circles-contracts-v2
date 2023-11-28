// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../lib/Math64x64.sol";
import "./IERC20.sol";

contract TemporalDiscount is IERC20 {
    // Constants

    /**
     * Decimals of tokens are set to 18
     */
    uint8 public constant DECIMALS = uint8(18);

    /**
     * Discount window reduces the resolution for calculating
     * the discount of balances from once per second (block.timestamp)
     * to once per week.
     *   1 week = 7 * 24 * 3600 seconds = 604800 seconds = 1 weeks
     */
    uint256 public constant DISCOUNT_WINDOW = 1 weeks;

    /**
     * Arbitrary origin for counting time since 10 December 2021
     *  "Hope" is the thing with feathers -
     */
    uint256 internal constant ZERO_TIME = uint256(1639094400);

    /**
     * EXA factor as 10^18
     */
    uint256 internal constant EXA = uint256(1000000000000000000);

    /**
     * Store the signed 128-bit 64.64 representation of 1 as a constant
     */
    int128 internal constant ONE_64x64 = int128(2 ** 64);

    /**
     * Reduction factor gamma for temporally discounting balances
     *   balance(t) = gamma^t * balance(t=0)
     * where 't' is expressed in units of DISCOUNT_WINDOW seconds,
     * and gamma is the reduction factor over that resolution window.
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

    // State variables

    /**
     * Creation time stores the time this time circle node was created
     */
    // note: this is not strictly needed, can remove later if we want to optimise
    uint256 public creationTime;

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

    /**
     * Temporal total supply stores the total supply at the time it was last updated.
     */
    uint256 private temporalTotalSupply;

    /**
     * Total supply time stores the time at which total supply was last written to.
     */
    uint256 private totalSupplyTime;

    mapping(address => mapping(address => uint256)) private allowances;

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

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // External functions

    function transfer(address _to, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        uint256 spentAllowance = allowances[_from][msg.sender] - _amount;
        _approve(_from, msg.sender, spentAllowance);
        _transfer(_from, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }

    function increaseAllowance(address _spender, uint256 _incrementAmount) external returns (bool) {
        uint256 increasedAllowance = allowances[msg.sender][_spender] + _incrementAmount;
        _approve(msg.sender, _spender, increasedAllowance);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _decreaseAmount) external returns (bool) {
        uint256 decreasedAllowance = allowances[msg.sender][_spender] - _decreaseAmount;
        _approve(msg.sender, _spender, decreasedAllowance);
        return true;
    }

    /**
     * @notice balanceOf returns the balance of owner discounted
     *         up to current time span.
     * @param _owner owns a temporally discounted balance of tokens.
     */
    function balanceOf(address _owner) external view returns (uint256 balance_) {
        uint256 currentSpan = _currentTimeSpan();
        if (balanceTimeSpans[_owner] == currentSpan) {
            // within the same time span balances are constant
            return balance_ = temporalBalances[_owner];
        } else {
            // preserve the expectation balanceOf as a view function
            // and don't store the computed result on read operations.
            return
                balance_ = _calculateDiscountedBalance(temporalBalances[_owner], currentSpan - balanceTimeSpans[_owner]);
        }
    }

    function totalSupply() external view returns (uint256 totalSupply_) {
        uint256 currentSpan = _currentTimeSpan();
        if (totalSupplyTime == currentSpan) {
            // no need to discount total supply
            return totalSupply_ = temporalTotalSupply;
        } else {
            // totalSupplyTime must be in the past of now
            uint256 numberOfTimeSpans = currentSpan - totalSupplyTime;
            // compute the reduction factor
            // note: same optimisation question as for _calculateDiscountedBalance()
            int128 reduction64x64 = Math64x64.pow(GAMMA_64x64, numberOfTimeSpans);
            // discounting the total supply is distributive over the sum of all individual balances
            totalSupply_ = Math64x64.mulu(reduction64x64, temporalTotalSupply);
            return totalSupply_;
        }
    }

    // Internal functions

    function _transfer(address _from, address _to, uint256 _amount) internal {
        uint256 currentSpan = _currentTimeSpan();
        _discountBalanceThenSubtract(_from, _amount, currentSpan);
        _discountBalanceThenAdd(_to, _amount, currentSpan);

        emit Transfer(_from, _to, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(address(_spender) != address(0), "Spender for approval must not be zero address.");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _mint(address _owner, uint256 _amount) internal {
        // note: we only call mint once from TimeCircles,
        // which already needs to calculate current time span,
        // but the pattern is off if we change the signature to pass currentSpan,
        // todo: evaluate if it is worth splitting the signatures for this...
        uint256 currentSpan = _currentTimeSpan();
        _discountTotalSupplyThenMint(_amount, currentSpan);
        _discountBalanceThenAdd(_owner, _amount, currentSpan);

        emit Transfer(address(0), _owner, _amount);
    }

    function _burn(address _owner, uint256 _amount) internal {
        uint256 currentSpan = _currentTimeSpan();
        _discountBalanceThenSubtract(_owner, _amount, currentSpan);
        _discountTotalSupplyThenBurn(_amount, currentSpan);

        emit Transfer(_owner, address(0), _amount);
    }

    /**
     * @notice current time span returns the count of time spans (counted in weeks)
     *         that have passed since ZERO_TIME.
     */
    function _currentTimeSpan() internal view returns (uint256 currentTimeSpan_) {
        // integer division rounds down, a difference less than one week
        // is counted as zero (since ZERO_TIME, or when substracting a difference)
        return ((block.timestamp - ZERO_TIME) / DISCOUNT_WINDOW);
    }

    // Private functions

    function _discountBalanceThenAdd(address _owner, uint256 _amount, uint256 _currentSpan)
        private
        returns (uint256 discountCost_)
    {
        if (balanceTimeSpans[_owner] == _currentSpan) {
            // Within the same time span balances are constant
            // so simply add the amount to the balance,
            // and no need to update the timespan.
            temporalBalances[_owner] = temporalBalances[_owner] + _amount;

            // opt to not emit DiscountCost event within same timespan
            return discountCost_ = uint256(0);
        } else {
            // if the balanceTimeSpan is small than currentSpan (only ever smaller)
            // calculate the discounted balance
            uint256 discountedBalance =
                _calculateDiscountedBalance(temporalBalances[_owner], _currentSpan - balanceTimeSpans[_owner]);
            // report the discount cost explicitly
            discountCost_ = temporalBalances[_owner] - discountedBalance;
            // and update the balance with the addition of the amount
            temporalBalances[_owner] = discountedBalance + _amount;
            // and update the timespan in which we updated the balance.
            balanceTimeSpans[_owner] = _currentSpan;

            // emit DiscountCost only when effectively discounted.
            // if the original balance was zero before adding,
            // discount cost can still be zero, even when discounted
            if (discountCost_ != uint256(0)) {
                emit DiscountCost(_owner, discountCost_);
            }
            return discountCost_;
        }
    }

    function _discountBalanceThenSubtract(address _owner, uint256 _amount, uint256 _currentSpan)
        private
        returns (uint256 discountCost_)
    {
        if (balanceTimeSpans[_owner] == _currentSpan) {
            // Within the same time span balances are constant
            // so simply subtract the amount from the balance,
            // and no need to update the timespan.
            temporalBalances[_owner] = temporalBalances[_owner] - _amount;

            // opt to not emit DiscountCost event within same timespan
            return discountCost_ = uint256(0);
        } else {
            // if the balanceTimeSpan is small than currentSpan (only ever smaller)
            // calculate the discounted balance
            uint256 discountedBalance =
                _calculateDiscountedBalance(temporalBalances[_owner], _currentSpan - balanceTimeSpans[_owner]);
            // report the discount cost explicitly
            discountCost_ = temporalBalances[_owner] - discountedBalance;
            // and update the balance with the addition of the amount
            temporalBalances[_owner] = discountedBalance - _amount;
            // and update the timespan in which we updated the balance.
            balanceTimeSpans[_owner] = _currentSpan;

            // emit DiscountCost only when effectively discounted.
            // note: there must have been some discount cost, because we subtracted
            //     an amount from the balance successfully.
            emit DiscountCost(_owner, discountCost_);
            return discountCost_;
        }
    }

    function _discountTotalSupplyThenMint(uint256 _amount, uint256 _currentSpan) private {
        if (totalSupplyTime == _currentSpan) {
            temporalTotalSupply += _amount;
        } else {
            uint256 discountedTotalSupply =
                _calculateDiscountedBalance(temporalTotalSupply, _currentSpan - totalSupplyTime);
            temporalTotalSupply = discountedTotalSupply + _amount;
            totalSupplyTime = _currentSpan;
        }
    }

    function _discountTotalSupplyThenBurn(uint256 _amount, uint256 _currentSpan) private {
        if (totalSupplyTime == _currentSpan) {
            temporalTotalSupply -= _amount;
        } else {
            uint256 discountedTotalSupply =
                _calculateDiscountedBalance(temporalTotalSupply, _currentSpan - totalSupplyTime);
            temporalTotalSupply = discountedTotalSupply - _amount;
            totalSupplyTime = _currentSpan;
        }
    }

    function _calculateDiscountedBalance(uint256 _balance, uint256 _numberOfTimeSpans)
        internal
        pure
        returns (uint256 discountedBalance_)
    {
        // don't call this function in the implementation
        // if there is no discount; let's not waste gas
        assert(_numberOfTimeSpans > 0);
        if (_numberOfTimeSpans == uint256(0)) return discountedBalance_ = _balance;
        // exponentiate the reduction factor by the number of time spans (of one week)
        // todo: as most often the number of time spans would be a low integer
        //       we can cache a table of the initial reduction factors.
        //       evaluate how much gas this would save;
        //       alternatively a cache table could be dynamically built.
        int128 reduction64x64 = ONE_64x64;
        if (_numberOfTimeSpans == uint256(1)) {
            reduction64x64 = GAMMA_64x64;
        } else {
            // for n >= 2
            reduction64x64 = Math64x64.pow(GAMMA_64x64, _numberOfTimeSpans);
        }
        // return the discounted balance
        discountedBalance_ = Math64x64.mulu(reduction64x64, _balance);
    }
}
