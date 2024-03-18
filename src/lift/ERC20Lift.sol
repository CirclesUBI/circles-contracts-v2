// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/utils/Create2.sol";
import "../errors/Errors.sol";
import "../proxy/ProxyFactory.sol";

contract ERC20Lift is ProxyFactory, ICirclesErrors {
    // Type declarations

    enum CirclesType {
        Demurrage,
        Inflation
    }

    // Constants

    bytes4 public constant ERC20_DEMURRAGE_SETUP_CALLPREFIX = bytes4(keccak256("setup(uint256)"));

    bytes4 public constant ERC20_INFLATION_SETUP_CALLPREFIX = bytes4(keccak256("setup(uint256)"));

    // State variables

    /**
     * @dev The master copy of the ERC20 demurrage Circles contract.
     */
    address public immutable masterCopyERC20Demurrage;

    /**
     * @dev The master copy of the ERC20 inflation Circles contract.
     */
    address public immutable masterCopyERC20Inflation;

    mapping(address => address) public erc20DemurrageCircles;

    mapping(address => address) public erc20InflationCircles;

    // Constructor

    constructor(address _masterCopyERC20Demurrage, address _masterCopyERC20Inflation) {
        if (_masterCopyERC20Demurrage == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(0);
        }
        if (_masterCopyERC20Inflation == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(1);
        }

        masterCopyERC20Demurrage = _masterCopyERC20Demurrage;
        masterCopyERC20Inflation = _masterCopyERC20Inflation;
    }

    // Public functions

    function ensureERC20Wrapper(uint256 _id, CirclesType _circlesType) public pure returns (address) {
        // todo: first build a simple proxy factory, afterwards redo for create2 deployment
        // bytes32 salt = keccak256(abi.encodePacked(_id));
    }

    function getDeterministicAddress(uint256 _tokenId, bytes32 _bytecodeHash) public view returns (address) {
        return Create2.computeAddress(keccak256(abi.encodePacked(_tokenId)), _bytecodeHash);
    }
}
