// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

contract BaseMintPolicyDefinitions {
    // Type declarations

    /**
     * @notice Base redemption policy to user specify desired collateral to redeem
     */
    struct BaseRedemptionPolicy {
        uint256[] redemptionIds;
        uint256[] redemptionValues;
    }
}
