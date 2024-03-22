// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../hub/IHub.sol";
import "../names/INameRegistry.sol";
import "./ERC20InflationaryBalances.sol";

contract InflationaryCircles is ERC20InflationaryBalances, ERC1155Holder {
    // Constants

    // State variables

    IHubV2 public hub;

    INameRegistry public nameRegistry;

    address public avatar;

    // Events

    event Deposit(address indexed account, uint256 amount, uint256 demurragedAmount);

    event Withdraw(address indexed account, uint256 amount, uint256 demurragedAmount);

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
            // Must not be initialized already.
            revert CirclesProxyAlreadyInitialized();
        }
        if (address(_hub) == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(0);
        }
        if (address(_nameRegistry) == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(1);
        }
        if (_avatar == address(0)) {
            // Must not be the zero address.
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
        uint256 extendedAmount = _burn(msg.sender, _amount);
        // calculate demurraged amount in extended accuracy representation
        // then discard garbage bits by shifting right
        uint256 demurragedAmount =
            convertInflationaryToDemurrageValue(extendedAmount, day(block.timestamp)) >> EXTENDED_ACCURACY_BITS;

        hub.safeTransferFrom(address(this), msg.sender, toTokenId(avatar), demurragedAmount, "");

        emit Withdraw(msg.sender, _amount, demurragedAmount);
    }

    function name() external view returns (string memory) {
        return string(abi.encodePacked(nameRegistry.name(avatar), "-F"));
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
        // calculate inflationary amount to mint to sender
        uint256 inflationaryAmount = _mintFromDemurragedAmount(_from, _amount);

        emit Deposit(_from, inflationaryAmount, _amount);

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
}
