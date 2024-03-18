// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface INameRegistry {
    function updateCidV0Digest(address avatar, bytes32 cidVoDigest) external;
    function isValidName(string calldata _name) external pure returns (bool);
    function isValidSymbol(string calldata _symbol) external pure returns (bool);
}
