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

    function tokenToUser(address /*token*/) external pure returns (address) {
        notMocked();
        return address(0);
    }
    function userToToken(address /*user*/) external pure returns (address) {
        notMocked();
        return address(0);
    }

    function limits(address /*truster*/, address /*trustee*/) external pure returns (uint256) {
        notMocked();
        return uint256(0);
    }

    function trust(address /*trustee*/, uint256 /*limit*/) external pure {
        notMocked();
    }

    function notMocked() private pure {
        assert(false);
    }
}