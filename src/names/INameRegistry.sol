// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface INameRegistry {
    function updateCidV0Digest(address avatar, bytes32 cidVoDigest) external;
    function registerName(address avatar, string calldata name) external;
    function registerSymbol(address avatar, string calldata symbol) external;

    function name(address avatar) external view returns (string memory);
    function symbol(address avatar) external view returns (string memory);

    function isValidName(string calldata name) external pure returns (bool);
    function isValidSymbol(string calldata symbol) external pure returns (bool);
}
