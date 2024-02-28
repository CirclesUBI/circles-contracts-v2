// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "../hub/IHub.sol";
import "./IStandardVault.sol";

contract standardVault is ERC165, IERC1155Receiver, IStandardVault {
    // State variables

    address public standardTreasury;

    IHubV2 public hub;

    // Modifiers

    modifier onlyTreasury() {
        require(msg.sender == standardTreasury, "Vault: caller is not the treasury");
        _;
    }

    // Constructor

    constructor() {
        standardTreasury = address(1);
    }

    // External functions

    function setup(IHubV2 _hub) external {
        require(address(hub) == address(0), "Vault: already initialized");
        standardTreasury = msg.sender;
        hub = _hub;
    }

    function returnCollateral(
        address _receiver,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external onlyTreasury {
        require(_receiver != address(0), "Vault: receiver cannot be 0 address");

        // return the collateral to the receiver
        hub.safeBatchTransferFrom(address(this), _receiver, _ids, _values, _data);
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
        // todo: register which collateral is stored in this vault?
        return this.onERC1155BatchReceived.selector;
    }
}
