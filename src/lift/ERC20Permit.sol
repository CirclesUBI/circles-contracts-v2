// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "../errors/Errors.sol";
import "./EIP712.sol";

contract ERC20Permit is EIP712, Nonces, IERC20Permit, IERC20Errors, ICirclesErrors {
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

    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (block.timestamp > _deadline) {
            revert ERC2612ExpiredSignature(_deadline);
        }

        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, _useNonce(_owner), _deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, _v, _r, _s);
        if (signer != _owner) {
            revert ERC2612InvalidSigner(signer, _owner);
        }

        _approve(_owner, _spender, _value);
    }

    function nonces(address _owner) public view override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(_owner);
    }

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    // Public functions

    // Internal functions

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        if (_owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[_owner][_spender] = _amount;
        emit IERC20.Approval(_owner, _spender, _amount);
    }

    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal {
        uint256 currentAllowance = _allowances[_owner][_spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < _amount) {
                revert ERC20InsufficientAllowance(_spender, currentAllowance, _amount);
            }
            unchecked {
                _approve(_owner, _spender, currentAllowance - _amount);
            }
        }
    }
}
