// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

contract MetadataDefinitions {
    // Type declarations

    struct Metadata {
        MetadataType metadataType;
        bytes metadata;
        bytes erc1155UserData;
    }

    struct GroupMintMetadata {
        address group;
    }

    // Enums

    enum MetadataType {
        NoMetadata,
        GroupMint // safeTransferFrom initiated from group mint, appends GroupMintMetadata
    }
}
