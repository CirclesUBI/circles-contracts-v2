// SPDX-License-Identifier: AGPL-3.0-only
// Taken from https://github.com/gnosis/safe-contracts
pragma solidity >=0.8.4;

contract MasterCopyNonUpgradable {
    /* Storage */

    /**
     * @dev This storage variable *MUST* be the first storage element
     *      for this contract.
     *
     *      A contract acting as a master copy for a proxy contract
     *      inherits from this contract. In inherited contracts list, this
     *      contract *MUST* be the first one. This would assure that
     *      the storage variable is always the first storage element for
     *      the inherited contract.
     *
     *      The proxy is applied to save gas during deployment, and importantly
     *      the proxy is not upgradable.
     */
    address internal reservedStorageSlotForProxy;
}
