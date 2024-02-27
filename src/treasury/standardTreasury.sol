// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "../proxy/ProxyFactory.sol";
import "../hub/MetadataDefinitions.sol";

contract standardTreasury is ERC165, IERC1155Receiver, ProxyFactory {
    // Constants

    /**
     * @dev The call prefix for the setup function on the vault contract
     */
    bytes4 public constant STANDARD_VAULT_SETUP_CALLPREFIX = bytes4(keccak256("setup(address)"));

    // State variables

    address public immutable hub;

    /**
     * @notice Mapping of group address to vault address
     * @dev The vault is the contract that holds the group's collateral
     * todo: we could use deterministic vault addresses as to not store them
     * but then we still need to check whether the correct code has been deployed
     * so we might as well deploy and store the addresses?
     */
    mapping(address => address) public vaults;

    // Modifiers

    modifier onlyHub() {
        require(msg.sender == hub, "Treasury: caller is not the hub");
        _;
    }

    // Constructor

    constructor(address _hub) {
        require(_hub != address(0), "Hub address cannot be 0");
        hub = _hub;
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
    ) public virtual override onlyHub returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory _data
    ) public virtual override onlyHub returns (bytes4) {
        MetadataDefinitions.Metadata memory metadata = abi.decode(_data, (MetadataDefinitions.Metadata));
        require(metadata.metadataType == MetadataDefinitions.MetadataType.GroupMint, "Treasury: Invalid metadata type");
        MetadataDefinitions.GroupMintMetadata memory groupMintMetadata =
            abi.decode(metadata.metadata, (MetadataDefinitions.GroupMintMetadata));

        return this.onERC1155BatchReceived.selector;
    }

    // Internal functions

    function _getVault(address _group) internal returns (address) {}
}
