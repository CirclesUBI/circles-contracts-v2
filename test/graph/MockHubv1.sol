// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/migration/IHub.sol";

contract MockHubV1 is IHubV1 {

    function signup() external {
        notMocked();
    }

    function organizationSignup() external {
        notMocked();
    }

    function tokenToUser(address token) external view returns (address) {
        notMocked();
        return address(0);
    }
    function userToToken(address user) external view returns (address) {
        notMocked();
        return address(0);
    }

    function limits(address truster, address trustee) external returns (uint256) {
        notMocked();
        return uint256(0);
    }

    function trust(address trustee, uint256 limit) external {
        notMocked();
    }

    function notMocked() private pure {
        assert(false);
    }
}