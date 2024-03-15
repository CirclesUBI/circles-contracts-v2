// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

contract MetadataDefinitions {
    // Type declarations

    struct Metadata {
        bytes32 metadataType;
        bytes metadata;
        bytes erc1155UserData;
    }

    struct GroupMintMetadata {
        address group;
    }

    // Constants

    bytes32 public constant METADATATYPE_GROUPMINT = keccak256("CIRCLESv2:RESERVED_DATA:CirclesGroupMint");
}
