// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "../errors/Errors.sol";
import "./ERC20DiscountedBalances.sol";

abstract contract DemurrageCircles is ERC20DiscountedBalances, ERC1155Holder, IERC20, IERC20Errors, ICirclesErrors {
    // Constants

    // State variables

    IHubV2 public hub;

    address public avatar;

    mapping(address => mapping(address => uint256)) private _allowances;

    // Modifiers

    modifier onlyHub() {
        if (msg.sender != address(hub)) {
            revert CirclesInvalidFunctionCaller(msg.sender, 0);
        }
        _;
    }

    // Constructor

    constructor() {
        // lock the master copy upon construction
        hub = IHubV2(address(0x1));
    }

    // Setup function

    function setup(address _avatar) external {
        require(address(hub) == address(0));
        require(_avatar != address(0));
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

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        _spendAllowance(_from, msg.sender, _amount);
        _transfer(_from, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    // todo: increaseAllowance and decreaseAllowance, and ERC20Permit

    function unwrap(uint256 _amount) external {
        _burn(msg.sender, _amount);
        hub.safeTransferFrom(address(this), msg.sender, toTokenId(avatar), _amount, "");
    }

    function balanceOf(address _account) external view returns (uint256) {
        return balanceOfOnDay(_account, day(block.timestamp));
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function totalSupply() external view returns (uint256) {
        return hub.balanceOf(address(this), toTokenId(avatar));
    }

    // Public functions

    function onERC1155Received(address, address _from, uint256 _id, uint256 _amount, bytes memory)
        public
        override
        onlyHub
        returns (bytes4)
    {
        if (_id != toTokenId(avatar)) revert CirclesInvalidCirclesId(_id, 0);
        _mint(_from, _amount);
        return this.onERC1155Received.selector;
    }

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

        emit Transfer(_from, _to, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        if (_owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal {
        uint256 currentAllowance = _allowances[_owner][_spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < _amount) {
                revert ERC20InsufficientAllowance(_spender, currentAllowance, _amount);
            }
            unchecked {
                _approve(_owner, _spender, currentAllowance - _amount);
            }
        }
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
