// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./EIP712.sol";

contract ERC20Permit is EIP712, Nonces, IERC20Permit {
    // Errors

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    // Constants

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    string private constant permitName = "Circles";

    string private constant permitVersion = "v2";

    // State variables

    mapping(address => mapping(address => uint256)) internal _allowances;

    // Constructor

    constructor() {}

    // Setup function

    function _setupPermit() internal {
        _setupEIP712(permitName, permitVersion);
    }

    // External functions

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        // require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        // bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce(owner), deadline));
        // bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hashStruct));
        // address signer = ecrecover(hash, v, r, s);
        // require(signer == owner, "ERC20Permit: invalid signature");

        // _allowances[owner][spender] = value;
        // emit Approval(owner, spender, value);
    }

    function nonces(address owner) public view override(IERC20Permit, Nonces) returns (uint256) {
        // return nonce(owner);
    }

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        // return _domainSeparatorV4(name(), "1");
    }

    // Public functions

    // Internal functions
}
