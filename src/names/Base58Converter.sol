// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

contract Base58Converter {
    string internal constant ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    function toBase58(uint256 _data) internal pure returns (string memory) {
        bytes memory b58 = new bytes(64); // More than enough length
        uint256 i = 0;
        while (_data > 0) {
            uint256 mod = _data % 58;
            b58[i++] = bytes(ALPHABET)[mod];
            _data = _data / 58;
        }
        // Reverse the string since the encoding works backwards
        return string(_reverse(b58, i));
    }

    function _reverse(bytes memory _b, uint256 _len) internal pure returns (bytes memory) {
        bytes memory reversed = new bytes(_len);
        for (uint256 i = 0; i < _len; i++) {
            reversed[i] = _b[_len - 1 - i];
        }
        return reversed;
    }
}
