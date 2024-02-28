// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

interface IStandardVault {
    function returnCollateral(address receiver, uint256[] calldata ids, uint256[] calldata values, bytes calldata data)
        external;
}
