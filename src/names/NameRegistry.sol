// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../hub/IHub.sol";

contract NameRegistry {
    // Constants

    /**
     * @notice The last ("biggest") name that can be assigned is "zzzzzzzzzzzz",
     * which is 1449225352009601191935 in decimal when converted from base58
     */
    uint72 public constant MAX_NAME = uint72(1449225352009601191935);

    // State variables

    /**
     * @notice The address of the hub contract where the address must have registered first
     */
    IHubV2 public immutable hub;

    /**
     * @notice a mapping from the address to the assigned name
     * @dev 9 bytes or uint72 fit 12 characters in base58 encoding
     */
    mapping(address => uint72) public names;

    /**
     * @notice a mapping from the name to the address
     */
    mapping(uint72 => address) public addresses;

    // Events

    event RegisterName(address indexed avatar, uint72 name, uint256 nonce);

    // Constructor

    constructor(IHubV2 _hub) {
        require(address(_hub) != address(0), "Hub cannot be the zero address.");
        hub = _hub;
    }

    // External functions

    /**
     * @notice Register a name for the avatar
     */
    function registerName() external {
        require(hub.avatars(msg.sender) != address(0), "Avatar has not been registered in the hub.");

        (uint72 name, uint256 nonce) = searchName(msg.sender);

        // assign the name to the address
        names[msg.sender] = name;
        // assign the address to the name
        addresses[name] = msg.sender;

        emit RegisterName(msg.sender, name, nonce);
    }

    /**
     * Registers a name for the avatar using a specific nonce if the name is available
     * @param _nonce nonce to be used in the calculation
     */
    function registerWithNonce(uint256 _nonce) external {
        require(names[msg.sender] == uint72(0), "Avatar already has a name assigned.");
        require(hub.avatars(msg.sender) != address(0), "Avatar has not been registered in the hub.");

        uint72 name = calculateNameWithNonce(msg.sender, _nonce);

        require(addresses[name] == address(0), "Name is already assigned.");

        // assign the name to the address
        names[msg.sender] = name;
        // assign the address to the name
        addresses[name] = msg.sender;

        emit RegisterName(msg.sender, name, _nonce);
    }

    // Public functions

    /**
     * Search for the first available name for the avatar and return the name and nonce
     * @param _avatar address for which the name is to be calculated
     * @return name_ name that can be assigned to the avatar
     * @return nonce_ nonce for which this name can be assigned
     */
    function searchName(address _avatar) public view returns (uint72 name_, uint256 nonce_) {
        require(names[_avatar] == uint72(0), "Avatar already has a name assigned.");

        while (true) {
            name_ = calculateNameWithNonce(_avatar, nonce_);

            if (addresses[name_] == address(0)) {
                // if the name is not yet assigned, let's keep it
                break;
            }
            // if the name is already assigned, increment the nonce and try again
            nonce_++;
        }

        return (name_, nonce_);
    }

    /**
     * Calculates a name for the avatar using a nonce
     * @param _avatar address for which the name is to be calculated
     * @param _nonce nonce to be used in the calculation
     */
    function calculateNameWithNonce(address _avatar, uint256 _nonce) public pure returns (uint72 name_) {
        // use keccak256 to generate a pseudo-random number
        bytes32 digest = keccak256(abi.encodePacked(_avatar, _nonce));
        // take the modulo of the digest to get a number between 0 and MAX_NAME
        name_ = uint72(uint256(digest) % (MAX_NAME + 1));
    }
}
