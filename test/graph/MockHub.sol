// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/migration/IHub.sol";

contract MockHubV1 is IHubV1 {
    function signup() external pure {
        notMocked();
    }

    function organizationSignup() external pure {
        notMocked();
    }

    function tokenToUser(address /*token*/ ) external pure returns (address) {
        notMocked();
        return address(0);
    }

    function userToToken(address /*user*/ ) external pure returns (address) {
        // notMocked();
        // return always zero addres, ie. "not signed up in v1"
        return address(0);
    }

    function limits(address, /*truster*/ address /*trustee*/ ) external pure returns (uint256) {
        notMocked();
        return uint256(0);
    }

    function trust(address, /*trustee*/ uint256 /*limit*/ ) external pure {
        notMocked();
    }

    // parameters taken from:
    // https://gnosisscan.io/address/0x29b9a7fbb8995b2423a71cc17cf9810798f6c543/advanced#readContract
    function deployedAt() public returns (uint256) {
        return uint256(1602786330);
    }

    function initialIssuance() public returns (uint256) {
        return uint256(92592592592592);
    }

    function inflation() public returns (uint256) {
        return uint256(107);
    }

    function divisor() public returns (uint256) {
        return uint256(100);
    }

    function period() public returns (uint256) {
        return uint256(31556952);
    }

    function periods() public returns (uint256) {
        return (block.timestamp - deployedAt()) / period();
    }

    function notMocked() private pure {
        assert(false);
    }
}
