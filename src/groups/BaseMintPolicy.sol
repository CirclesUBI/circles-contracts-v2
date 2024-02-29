// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./IMintPolicy.sol";
import "./Definitions.sol";

abstract contract MintPolicy is IMintPolicy {
    /**
     * @notice Simple mint policy that always returns true
     * @param _minter Address of the minter
     * @param _group Address of the group
     * @param _collateral Array of collateral addresses
     * @param _amounts Array of collateral amounts
     * @param _data Optional data bytes passed to mint policy
     */
    function beforeMintPolicy(
        address _minter,
        address _group,
        address[] calldata _collateral,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external virtual override returns (bool) {
        return true;
    }

    function beforeBurnPolicy(address _burner, address _group, uint256 _value, bytes calldata _data)
        external
        virtual
        override
        returns (bool)
    {
        return true;
    }

    function beforeRedeemPolicy(
        address _operator,
        address _redeemer,
        address _group,
        uint256 _value,
        bytes calldata _data
    )
        external
        virtual
        override
        returns (
            uint256[] memory _ids,
            uint256[] memory _values,
            uint256[] memory _burnIds,
            uint256[] memory _burnValues
        )
    {
        // simplest policy is to return the collateral as the caller requests it in data
        BaseMintPolicyDefinitions.BaseRedemptionPolicy memory redemption =
            abi.decode(_data, (BaseMintPolicyDefinitions.BaseRedemptionPolicy));

        // and no collateral gets burnt upon redemption
        _burnIds = new uint256[](0);
        _burnValues = new uint256[](0);

        // standard treasury checks whether the total sums add up to the amount of group Circles redeemed
        // so we can simply decode and pass the request back to treasury.
        // The redemption will fail if it does not contain (sufficient of) these Circles
        return (redemption.redemptionIds, redemption.redemptionValues, _burnIds, _burnValues);
    }
}
