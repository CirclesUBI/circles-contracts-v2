// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "./ERC20DiscountedBalances.sol";

abstract contract DemurrageCircles is ERC20DiscountedBalances, IERC20, IERC20Errors {
    // Constants

    // State variables

    IHubV2 public hub;

    address public avatar;

    // Constructor

    constructor() {
        // lock the master copy upon construction
        hub = IHubV2(address(0x1));
    }

    // Setup function

    function setup(address _avatar) external {
        require(address(hub) == address(0), "Already initialized.");
        require(_avatar != address(0), "Avatar cannot be the zero address.");
        hub = IHubV2(msg.sender);
        avatar = _avatar;
        // read inflation day zero from hub
        inflationDayZero = hub.inflationDayZero();
    }

    // External functions

    function transfer(address _to, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return balanceOfOnDay(_account, day(block.timestamp));
    }

    // Public functions

    function circlesIdentifier() public view returns (uint256) {
        return toTokenId(avatar);
    }

    // Internal functions

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
    }
}
