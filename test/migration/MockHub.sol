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

    // simplify to boolean trust
    mapping(address => mapping(address => bool)) public trusts;

    mapping(address => address) public userToToken;
    mapping(address => address) public tokenToUser;

    // External functions

    function signup() external {
        require(address(userToToken[msg.sender]) == address(0), "You can't sign up twice");

        Token token = new Token(msg.sender);
        userToToken[msg.sender] = address(token);
        tokenToUser[address(token)] = msg.sender;
        // every user must trust themselves with a weight of 100
        // this is so that all users accept their own token at all times
        trust(msg.sender, 100);
    }

    function organizationSignup() external pure {
        notMocked();
    }

    function limits(address, /*truster*/ address /*trustee*/ ) external pure returns (uint256) {
        notMocked();
        return uint256(0);
    }

    function trust(address _trustee, uint256 _limit) public {
        trusts[msg.sender][_trustee] = _limit > 0 ? true : false;
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
