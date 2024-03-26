// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../hub/IHub.sol";
import "../names/INameRegistry.sol";
import "./ERC20DiscountedBalances.sol";

contract DemurrageCircles is ERC20DiscountedBalances, ERC1155Holder {
    // Constants

    // State variables

    IHubV2 public hub;

    INameRegistry public nameRegistry;

    address public avatar;

    // Events

    event Deposit(address indexed account, uint256 amount, uint256 inflationaryAmount);

    event Withdraw(address indexed account, uint256 amount, uint256 inflationaryAmount);

    // Modifiers

    modifier onlyHub(uint8 _code) {
        if (msg.sender != address(hub)) {
            revert CirclesInvalidFunctionCaller(msg.sender, address(hub), _code);
        }
        _;
    }

    // Constructor

    constructor() {
        // lock the master copy upon construction
        hub = IHubV2(address(0x1));
    }

    // Setup function

    function setup(IHubV2 _hub, INameRegistry _nameRegistry, address _avatar) external {
        if (address(hub) != address(0)) {
            revert CirclesProxyAlreadyInitialized();
        }
        if (address(_hub) == address(0)) {
            revert CirclesAddressCannotBeZero(0);
        }
        if (address(_nameRegistry) == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(1);
        }
        if (_avatar == address(0)) {
            revert CirclesAddressCannotBeZero(2);
        }
        hub = _hub;
        avatar = _avatar;
        // read inflation day zero from hub
        inflationDayZero = hub.inflationDayZero();

        _setupPermit();
    }

    // External functions

    function unwrap(uint256 _amount) external {
        _burn(msg.sender, _amount);
        hub.safeTransferFrom(address(this), msg.sender, toTokenId(avatar), _amount, "");

        uint256 inflationaryAmount = _calculateInflationaryBalance(_amount, day(block.timestamp));

        emit Withdraw(msg.sender, _amount, inflationaryAmount);
    }

    function totalSupply() external view override returns (uint256) {
        return hub.balanceOf(address(this), toTokenId(avatar));
    }

    function name() external view returns (string memory) {
        // append the suffix "-ERC20" to the ERC20 name of the Circles
        return string(abi.encodePacked(nameRegistry.name(avatar), "-ERC20"));
    }

    function symbol() external view returns (string memory) {
        return nameRegistry.symbol(avatar);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    // Public functions

    function onERC1155Received(address, address _from, uint256 _id, uint256 _amount, bytes memory)
        public
        override
        onlyHub(0)
        returns (bytes4)
    {
        if (_id != toTokenId(avatar)) revert CirclesInvalidCirclesId(_id, 0);
        _mint(_from, _amount);

        uint256 inflationaryAmount = _calculateInflationaryBalance(_amount, day(block.timestamp));

        emit Deposit(_from, _amount, inflationaryAmount);

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        view
        override
        onlyHub(1)
        returns (bytes4)
    {
        revert CirclesERC1155CannotReceiveBatch(0);
    }

    function circlesIdentifier() public view returns (uint256) {
        return toTokenId(avatar);
    }
}
