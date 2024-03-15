// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../circles/Demurrage.sol";
import "../hub/IHub.sol";

contract ERC20DiscountedBalances is Demurrage {
    // Constants

    // State variables

    /**
     * @dev The mapping of addresses to the discounted balances.
     */
    mapping(address => DiscountedBalance) public discountedBalances;

    // Constructor

    // External functions

    // Public functions

    function balanceOfOnDay(address _account, uint64 _day) public view returns (uint256) {
        DiscountedBalance memory discountedBalance = discountedBalances[_account];
        return _calculateDiscountedBalance(discountedBalance.balance, _day - discountedBalance.lastUpdatedDay);
    }

    // Internal functions

    function _inflationaryBalanceOf(address _account) internal view returns (uint256) {
        DiscountedBalance memory discountedBalance = discountedBalances[_account];
        return _calculateInflationaryBalance(discountedBalance.balance, discountedBalance.lastUpdatedDay);
    }

    function _updateBalance(address _account, uint256 _balance, uint64 _day) internal {
        require(_balance <= MAX_VALUE, "Balance exceeds maximum value.");
        DiscountedBalance storage discountedBalance = discountedBalances[_account];
        discountedBalance.balance = uint192(_balance);
        discountedBalance.lastUpdatedDay = _day;
    }

    function _discountAndAddToBalance(address _account, uint256 _value, uint64 _day) internal {
        DiscountedBalance storage discountedBalance = discountedBalances[_account];
        uint256 newBalance =
            _calculateDiscountedBalance(discountedBalance.balance, _day - discountedBalance.lastUpdatedDay) + _value;
        require(newBalance <= MAX_VALUE, "Balance exceeds maximum value.");
        discountedBalance.balance = uint192(newBalance);
        discountedBalance.lastUpdatedDay = _day;
    }
}
