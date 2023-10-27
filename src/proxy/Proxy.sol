// SPDX-License-Identifier: AGPL-3.0-only
// Adapted from https://github.com/gnosis/safe-contracts
pragma solidity >=0.8.4;

/// @title IProxy - interface to access master copy of the proxy on-chain
interface IProxy {
    function masterCopy() external view returns (address);
}

/// @title Proxy - Generic proxy contract allows to execute all transactions
///        applying the code of a master contract.
/// @author Stefan George - <stefan@gnosis.io>
/// @author Richard Meissner - <richard@gnosis.io>
contract Proxy {
    // masterCopy always needs to be first declared variable,
    // to ensure that it is at the same location in the contracts
    // to which calls are delegated.
    // To reduce deployment costs this variable is internal
    // and needs to be retrieved via `getStorageAt`
    address internal masterCopy;

    /// @dev Constructor function sets address of master copy contract.
    /// @param _masterCopy Master copy address.
    constructor(address _masterCopy) {
        require(
            _masterCopy != address(0),
            "Invalid master copy address provided"
        );
        masterCopy = _masterCopy;
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }

    // -- internal functions

    /// @dev Fallback function forwards all transactions and
    ///      returns all received return data.
    function _fallback() internal  {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let _singleton := and(
                sload(0),
                0xffffffffffffffffffffffffffffffffffffffff
            )
            // 0xa619486e == keccak("masterCopy()").
            // The value is right padded to 32-bytes with 0s
            // solhint-disable-next-line max-line-length
            if eq(calldataload(0), 0xa619486e00000000000000000000000000000000000000000000000000000000)
            {
                mstore(0, _singleton)
                return(0, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            // solhint-disable-next-line max-line-length
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
