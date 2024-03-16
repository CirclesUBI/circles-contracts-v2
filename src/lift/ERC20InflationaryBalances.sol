// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../circles/Demurrage.sol";
import "./ERC20Permit.sol";

abstract contract ERC20InflationaryBalances is ERC20Permit, Demurrage, IERC20 {
    // Constants

    uint8 internal constant EXTENDED_ACCURACY_BITS = 64;

    // State variables

    uint256 internal _extendedTotalSupply;

    mapping(address => uint256) private _extendedAccuracyBalances;

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
        return _extendedAccuracyBalances[_account] >> EXTENDED_ACCURACY_BITS;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function totalSupply() external view returns (uint256) {
        return _extendedTotalSupply >> EXTENDED_ACCURACY_BITS;
    }

    // Internal functions

    function _convertToExtended(uint256 _amount) internal pure returns (uint256) {
        if (_amount > MAX_VALUE) revert CirclesAmountOverflow(_amount, 0);
        return _amount << EXTENDED_ACCURACY_BITS;
    }

    function _transfer(address _from, address _to, uint256 _amount) internal {
        uint256 extendedAmount = _convertToExtended(_amount);
        uint256 extendedFromBalance = _extendedAccuracyBalances[_from];
        if (extendedFromBalance < extendedAmount) {
            revert ERC20InsufficientBalance(_from, extendedFromBalance >> EXTENDED_ACCURACY_BITS, _amount);
        }
        unchecked {
            _extendedAccuracyBalances[_from] = extendedFromBalance - extendedAmount;
            // rely on total supply not having overflowed
            _extendedAccuracyBalances[_to] += extendedAmount;
        }
        emit Transfer(_from, _to, _amount);
    }

    function _mintFromDemurragedAmount(address _owner, uint256 _demurragedAmount) internal {
        // first convert to extended accuracy representation so we have extra garbage bits,
        // before we apply the inflation factor, which will produce errors in the least significant bits
        uint256 extendedAmount =
            _calculateInflationaryBalance(_convertToExtended(_demurragedAmount), day(block.timestamp));
        // here ensure total supply does not overflow
        _extendedTotalSupply += extendedAmount;
        unchecked {
            _extendedAccuracyBalances[_owner] += extendedAmount;
        }
        emit Transfer(address(0), _owner, extendedAmount >> EXTENDED_ACCURACY_BITS);
    }

    function _burn(address _owner, uint256 _amount) internal returns (uint256) {
        uint256 extendedAmount = _convertToExtended(_amount);
        uint256 extendedOwnerBalance = _extendedAccuracyBalances[_owner];
        if (extendedOwnerBalance < extendedAmount) {
            revert ERC20InsufficientBalance(_owner, _extendedAccuracyBalances[_owner], _amount);
        }
        unchecked {
            _extendedAccuracyBalances[_owner] = extendedOwnerBalance - extendedAmount;
            // rely on total supply tracking complete sum of balances
            _extendedTotalSupply -= extendedAmount;
        }
        emit Transfer(_owner, address(0), _amount);

        return extendedAmount;
    }
}
