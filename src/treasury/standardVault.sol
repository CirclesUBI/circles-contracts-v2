// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract standardVault is ERC165, IERC1155Receiver {
    // State variables

    address public standardTreasury;

    // Constructor

    constructor() {
        standardTreasury = address(1);
    }

    // External functions

    function setup(address _standardTreasury) external {
        require(standardTreasury == address(0), "Vault contract has already been setup.");
        require(_standardTreasury != address(0), "Treasury address must not be zero address");
        standardTreasury = _standardTreasury;
    }

    // Public functions

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address, /*_operator*/
        address, /*_from*/
        uint256, /*_id*/
        uint256, /*_value*/
        bytes memory /*_data*/
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address, /*_operator*/
        address, /*_from*/
        uint256[] memory, /*_ids*/
        uint256[] memory, /*_values*/
        bytes memory /*_data*/
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
