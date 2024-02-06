// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../multitoken-graph/IHub.sol";

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
        require(names[msg.sender] == uint72(0), "Avatar already has a name assigned.");
        require(hub.avatars(msg.sender) != address(0), "Avatar has not been registered in the hub.");

        uint256 nonce = 0;
        uint72 name = 0;

        while (true) {
            // use keccak256 to generate a pseudo-random number
            bytes32 digest = keccak256(abi.encodePacked(msg.sender, nonce));
            // take the modulo of the digest to get a number between 0 and MAX_NAME
            name = uint72(uint256(digest) % (MAX_NAME + 1));

            if (addresses[name] == address(0)) {
                // if the name is not yet assigned, assign it
                break;
            }
            // if the name is already assigned, increment the nonce and try again
            nonce++;
        }

        // assign the name to the address
        names[msg.sender] = name;
        // assign the address to the name
        addresses[name] = msg.sender;

        emit RegisterName(msg.sender, name, nonce);
    }
}
