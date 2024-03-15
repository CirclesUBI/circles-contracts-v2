// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../circles/Demurrage.sol";
import "./ERC20Permit.sol";

contract ERC20DiscountedBalances is ERC20Permit, Demurrage, IERC20 {
    // Constants

    // State variables

    /**
     * @dev The mapping of addresses to the discounted balances.
     */
    mapping(address => DiscountedBalance) public discountedBalances;

    // Constructor

    // External functions

    function transfer(address _to, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        _spendAllowance(_from, msg.sender, _amount);
        _transfer(_from, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][_spender];
        _approve(msg.sender, _spender, currentAllowance + _addedValue);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][_spender];
        if (_subtractedValue >= currentAllowance) {
            _approve(msg.sender, _spender, 0);
        } else {
            unchecked {
                _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
            }
        }
        return true;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return balanceOfOnDay(_account, day(block.timestamp));
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function totalSupply() external view virtual returns (uint256) {
        return uint256(0);
    }

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

    function _transfer(address _from, address _to, uint256 _amount) internal {
        uint64 day = day(block.timestamp);
        uint256 fromBalance = balanceOfOnDay(_from, day);
        if (fromBalance < _amount) {
            revert ERC20InsufficientBalance(_from, fromBalance, _amount);
        }
        unchecked {
            _updateBalance(_from, fromBalance - _amount, day);
        }
        _discountAndAddToBalance(_to, _amount, day);

        emit Transfer(_from, _to, _amount);
    }

    function _mint(address _owner, uint256 _amount) internal {
        _discountAndAddToBalance(_owner, _amount, day(block.timestamp));
        emit Transfer(address(0), _owner, _amount);
    }

    function _burn(address _owner, uint256 _amount) internal {
        uint64 day = day(block.timestamp);
        uint256 ownerBalance = balanceOfOnDay(_owner, day);
        if (ownerBalance < _amount) {
            revert ERC20InsufficientBalance(_owner, ownerBalance, _amount);
        }
        unchecked {
            _updateBalance(_owner, ownerBalance - _amount, day);
        }
        emit Transfer(_owner, address(0), _amount);
    }
}
