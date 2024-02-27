// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../proxy/ProxyFactory.sol";

contract standardTreasury is ERC1155Holder, ProxyFactory {
    // State variables

    address public immutable hub;

    // modifier

    modifier onlyHub() {
        require(msg.sender == hub, "Treasury: caller is not the hub");
        _;
    }

    // Constructor

    constructor(address _hub) {
        require(_hub != address(0), "Hub address cannot be 0");
        hub = _hub;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory)
        public
        virtual
        override
        onlyHub
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        virtual
        override
        onlyHub
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}
