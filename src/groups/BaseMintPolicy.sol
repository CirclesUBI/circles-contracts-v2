// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./IMintPolicy.sol";

abstract contract MintPolicy is IMintPolicy {
    /**
     * @notice Simple mint policy that always returns true
     * @param minter Address of the minter
     * @param group Address of the group
     * @param collateral Array of collateral addresses
     * @param amounts Array of collateral amounts
     * @param data Optional data bytes passed to mint policy
     */
    function beforeMintPolicy(
        address minter,
        address group,
        address[] calldata collateral,
        uint256[] calldata amounts,
        bytes calldata data
    ) external virtual override returns (bool) {
        return true;
    }
}
