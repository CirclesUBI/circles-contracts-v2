// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../../src/migration/IHub.sol";
import "./MockToken.sol";

contract MockHubV1 is IHubV1 {
    // Constants

    // parameters taken from:
    // https://gnosisscan.io/address/0x29b9a7fbb8995b2423a71cc17cf9810798f6c543/advanced#readContract
    uint256 public constant deployedAt = uint256(1602786330);
    uint256 public constant initialIssuance = uint256(92592592592592);
    uint256 public constant timeout = uint256(7776000);
    uint256 public constant inflation = uint256(107);
    uint256 public constant divisor = uint256(100);
    uint256 public constant period = uint256(31556952);
    uint256 public constant signupBonus = uint256(50000000000000000000);
    string public constant name = "CirclesV1";
    string public constant symbol = "CRC";

    // State variables

    mapping(address => address) public userToToken;

    // External functions

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

    function limits(address, /*truster*/ address /*trustee*/ ) external pure returns (uint256) {
        notMocked();
        return uint256(0);
    }

    function trust(address, /*trustee*/ uint256 /*limit*/ ) external pure {
        notMocked();
    }

    function issuance() external view returns (uint256) {
        return inflate(initialIssuance, periods());
    }

    function inflate(uint256 _initial, uint256 _periods) public pure returns (uint256) {
        // copy of the implementation from circles contracts v1
        // to mirror the same numerical errors as hub v1 has.
        // https://github.com/CirclesUBI/circles-contracts/blob/master/contracts/Hub.sol#L96-L103
        uint256 q = pow(inflation, _periods);
        uint256 d = pow(divisor, _periods);
        return (_initial * q) / d;
    }

    /// @notice finds the inflation rate at a given inflation period
    /// @param _periods the step to calculate the issuance rate at
    /// @return inflation rate as of the given period
    function issuanceByStep(uint256 _periods) public pure returns (uint256) {
        return inflate(initialIssuance, _periods);
    }

    function periods() public view returns (uint256) {
        return (block.timestamp - deployedAt) / period;
    }

    // Public functions

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

    // Private functions

    function notMocked() private pure {
        assert(false);
    }
}
