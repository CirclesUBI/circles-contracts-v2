// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Graph is ERC1155 {
    // State variables

    // linked list for registered avatars
    mapping(address => address) public avatars;

    // linked list for registered groups
    mapping(address => address) public groups;

    // linked list for registered organizations
    mapping(address => address) public organizations;

    mapping(uint256 => bytes32) public avatarIpfsUris;

    // Constructor

    constructor() ERC1155("https://fallback.aboutcircles.com/v1/profile/{id}.json") {}



    function uri(uint256 _id) external view override returns (string memory uri_) {
        if (avatarIpfsUris[_id] != bytes32(0)) {
            return uri_ = string(abi.encodedPacked("ipfs://f0", bytes32ToHex(avatarIpfsUris[_id]);
        }
    }
}