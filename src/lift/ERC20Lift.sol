// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/utils/Create2.sol";
import "../errors/Errors.sol";
import "../lift/IERC20Lift.sol";
import "../hub/IHub.sol";
import "../proxy/ProxyFactory.sol";

contract ERC20Lift is ProxyFactory, IERC20Lift, ICirclesErrors {
    // Constants

    bytes4 public constant ERC20_WRAPPER_SETUP_CALLPREFIX = bytes4(keccak256("setup(address,address)"));

    // State variables

    IHubV2 public immutable hub;

    /**
     * @dev The master copy of the ERC20 demurrage and inflation Circles contract.
     */
    address[2] public masterCopyERC20Wrapper;

    mapping(CirclesType => mapping(address => address)) public erc20Circles;

    // Constructor

    constructor(IHubV2 _hub, address _masterCopyERC20Demurrage, address _masterCopyERC20Inflation) {
        if (address(_hub) == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(0);
        }
        if (_masterCopyERC20Demurrage == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(1);
        }
        if (_masterCopyERC20Inflation == address(0)) {
            // Must not be the zero address.
            revert CirclesAddressCannotBeZero(2);
        }

        hub = _hub;

        masterCopyERC20Wrapper[uint256(CirclesType.Demurrage)] = _masterCopyERC20Demurrage;
        masterCopyERC20Wrapper[uint256(CirclesType.Inflation)] = _masterCopyERC20Inflation;
    }

    // Public functions

    function ensureERC20(address _avatar, CirclesType _circlesType) public returns (address) {
        // todo: first build a simple proxy factory, afterwards redo for create2 deployment
        // bytes32 salt = keccak256(abi.encodePacked(_id));
        if (_circlesType != CirclesType.Demurrage && _circlesType != CirclesType.Inflation) {
            // Must be a valid CirclesType.
            revert CirclesInvalidParameter(uint256(_circlesType), 0);
        }

        if (msg.sender != address(hub)) {
            // if the Hub calls it already has checked valid avatar
            if (hub.avatars(_avatar) == address(0)) {
                // Avatar must be registered.
                revert CirclesAvatarMustBeRegistered(_avatar, 0);
            }
        }

        address erc20Wrapper = erc20Circles[_circlesType][_avatar];
        if (erc20Wrapper == address(0)) {
            erc20Wrapper = _deployERC20(masterCopyERC20Wrapper[uint256(_circlesType)], _avatar);
            erc20Circles[_circlesType][_avatar] = erc20Wrapper;
        }
        return erc20Wrapper;
    }

    function getDeterministicAddress(uint256 _tokenId, bytes32 _bytecodeHash) public view returns (address) {
        return Create2.computeAddress(keccak256(abi.encodePacked(_tokenId)), _bytecodeHash);
    }

    // Internal functions

    function _deployERC20(address _masterCopy, address _avatar) internal returns (address) {
        bytes memory wrapperSetupData = abi.encodeWithSelector(ERC20_WRAPPER_SETUP_CALLPREFIX, hub, _avatar);
        address erc20wrapper = address(_createProxy(_masterCopy, wrapperSetupData));
        return erc20wrapper;
    }
}
