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

    function beforeRedeemPolicy(address operator, address redeemer, address group, uint256 value, bytes calldata data)
        external
        returns (
            uint256[] memory redemptionIds,
            uint256[] memory redemptionValues,
            uint256[] memory burnIds,
            uint256[] memory burnValues
        );

    function beforeBurnPolicy(address burner, address group, uint256 value, bytes calldata data)
        external
        returns (bool);
}
