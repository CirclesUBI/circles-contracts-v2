// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "src/migration/IHub.sol";

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
    function deployedAt() public pure returns (uint256) {
        return uint256(1602786330);
    }

    function initialIssuance() public pure returns (uint256) {
        return uint256(92592592592592);
    }

    function inflate(uint256 _initial, uint256 _periods) public pure returns (uint256) {
        // copy of the implementation from circles contracts v1
        // to mirror the same numerical errors as hub v1 has.
        // https://github.com/CirclesUBI/circles-contracts/blob/master/contracts/Hub.sol#L96-L103
        uint256 q = pow(inflation(), _periods);
        uint256 d = pow(divisor(), _periods);
        return (_initial * q) / d;
    }

    function inflation() public pure returns (uint256) {
        return uint256(107);
    }

    function divisor() public pure returns (uint256) {
        return uint256(100);
    }

    function period() public pure returns (uint256) {
        return uint256(31556952);
    }

    function periods() public view returns (uint256) {
        return (block.timestamp - deployedAt()) / period();
    }

    // Private functions

    function notMocked() private pure {
        assert(false);
    }

    /// @dev this is an implementation of exponentiation by squares
    /// @param base the base to be used in the calculation
    /// @param exponent the exponent to be used in the calculation
    /// @return the result of the calculation
    function pow(uint256 base, uint256 exponent) public pure returns (uint256) {
        if (base == 0) {
            return 0;
        }
        if (exponent == 0) {
            return 1;
        }
        if (exponent == 1) {
            return base;
        }
        uint256 y = 1;
        while (exponent > 1) {
            if (exponent % 2 == 0) {
                base = base * base;
                exponent = exponent / 2;
            } else {
                y = base * y;
                base = base * base;
                exponent = (exponent - 1) / 2;
            }
        }
        return base * y;
    }
}
