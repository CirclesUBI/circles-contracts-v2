// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IMintPolicy {
    function beforeMintPolicy(
        address minter,
        address group,
        address[] calldata collateral,
        uint256[] calldata amounts,
        bytes calldata data
    ) external returns (bool);
}
