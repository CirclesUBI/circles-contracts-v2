// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "../proxy/ProxyFactory.sol";
import "../hub/MetadataDefinitions.sol";
import "../hub/IHub.sol";
import "../groups/IMintPolicy.sol";
import "./IStandardVault.sol";

contract standardTreasury is ERC165, IERC1155Receiver, ProxyFactory {
    // Constants

    /**
     * @dev The call prefix for the setup function on the vault contract
     */
    bytes4 public constant STANDARD_VAULT_SETUP_CALLPREFIX = bytes4(keccak256("setup()"));

    // State variables

    /**
     * @notice Address of the hub contract
     */
    IHubV2 public immutable hub;

    /**
     * @notice Address of the mastercopy standard vault contract
     */
    address public immutable mastercopyStandardVault;

    /**
     * @notice Mapping of group address to vault address
     * @dev The vault is the contract that holds the group's collateral
     * todo: we could use deterministic vault addresses as to not store them
     * but then we still need to check whether the correct code has been deployed
     * so we might as well deploy and store the addresses?
     */
    mapping(address => IStandardVault) public vaults;

    // Modifiers

    modifier onlyHub() {
        require(msg.sender == address(hub), "Treasury: caller is not the hub");
        _;
    }

    // Constructor

    constructor(IHubV2 _hub, address _mastercopyStandardVault) {
        require(address(_hub) != address(0), "Hub address cannot be 0");
        require(_mastercopyStandardVault != address(0), "Mastercopy standard vault address cannot be 0");
        hub = _hub;
        mastercopyStandardVault = _mastercopyStandardVault;
    }

    // Public functions

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Exclusively use single received for receiving group Circles to redeem them
     * for collateral Circles according to the group mint policy
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes memory _data)
        public
        virtual
        override
        returns (bytes4)
    {
        address group = _validateCirclesIdToGroup(_id);
        IStandardVault vault = vaults[group];
        require(address(vault) != address(0), "Treasury: Group has no vault");

        // query the hub for the mint policy
        IMintPolicy policy = IMintPolicy(hub.mintPolicies(group));
        require(address(policy) != address(0), "Treasury: Invalid group without mint policy");

        // query the mint policy for the redemption values
        uint256[] memory redemptionIds;
        uint256[] memory redemptionValues;
        (redemptionIds, redemptionValues) = policy.beforeRedeemPolicy(_operator, _from, group, _value, _data);

        // ensure the redemption values sum up to the correct amount
        uint256 sum = 0;
        for (uint256 i = 0; i < redemptionValues.length; i++) {
            sum += redemptionValues[i];
        }
        require(sum == _value, "Treasury: Invalid redemption values from policy");

        // burn the group Circles
        hub.burn(_id, _value);

        // return collateral Circles to the redeemer of group Circles
        vault.returnCollateral(_from, redemptionIds, redemptionValues, _data);

        return this.onERC1155Received.selector;
    }

    /**
     * @dev Exclusively use batch received for receiving collateral Circles
     * from the hub contract during group minting
     */
    function onERC1155BatchReceived(
        address, /*_operator*/
        address _from,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory _data
    ) public virtual override onlyHub returns (bytes4) {
        // decode the data to get the group address
        MetadataDefinitions.Metadata memory metadata = abi.decode(_data, (MetadataDefinitions.Metadata));
        require(metadata.metadataType == MetadataDefinitions.MetadataType.GroupMint, "Treasury: Invalid metadata type");
        MetadataDefinitions.GroupMintMetadata memory groupMintMetadata =
            abi.decode(metadata.metadata, (MetadataDefinitions.GroupMintMetadata));
        // ensure the vault exists
        address vault = address(_ensureVault(groupMintMetadata.group));
        // forward the Circles to the vault
        hub.safeBatchTransferFrom(address(this), vault, _ids, _values, metadata.erc1155UserData);
        return this.onERC1155BatchReceived.selector;
    }

    // Internal functions

    function _validateCirclesIdToGroup(uint256 _id) internal pure returns (address) {
        address group = address(uint160(_id));
        require(uint256(uint160(group)) == _id, "Treasury: Invalid group Circles id");
        return group;
    }

    function _ensureVault(address _group) internal returns (IStandardVault) {
        IStandardVault vault = vaults[_group];
        if (address(vault) == address(0)) {
            vault = _deployVault();
            vaults[_group] = vault;
        }
        return vault;
    }

    // todo: this could be done with deterministic deployment, but same comment, not worth it
    function _deployVault() internal returns (IStandardVault) {
        bytes memory vaultSetupData = abi.encodeWithSelector(STANDARD_VAULT_SETUP_CALLPREFIX);
        IStandardVault vault = IStandardVault(address(_createProxy(mastercopyStandardVault, vaultSetupData)));
        return vault;
    }
}
