// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../errors/Errors.sol";
import "../hub/IHub.sol";

contract NameRegistry is INameRegistryErrors {
    // Constants

    /**
     * @notice The last ("biggest") short name that can be assigned is "zzzzzzzzzzzz",
     * which is 1449225352009601191935 in decimal when converted from base58
     */
    uint72 public constant MAX_SHORT_NAME = uint72(1449225352009601191935);

    // State variables

    /**
     * @notice The address of the hub contract where the address must have registered first
     */
    // IHubV2 public immutable hub;

    /**
     * @notice a mapping from the address to the assigned name
     * @dev 9 bytes or uint72 fit 12 characters in base58 encoding
     */
    mapping(address => uint72) public shortNames;

    /**
     * @notice a mapping from the short name to the address
     */
    mapping(uint72 => address) public addresses;

    // Events

    event RegisterShortName(address indexed avatar, uint72 shortName, uint256 nonce);

    // Constructor

    constructor() { // (IHubV2 _hub) {
            // require(address(_hub) != address(0), "Hub cannot be the zero address.");
            // hub = _hub;
    }

    // External functions

    /**
     * @notice Register a short name for the avatar
     */
    function registerShortName() external {
        // require(hub.avatars(msg.sender) != address(0), "Avatar has not been registered in the hub.");

        (uint72 shortName, uint256 nonce) = searchShortName(msg.sender);

        // assign the name to the address
        shortNames[msg.sender] = shortName;
        // assign the address to the name
        addresses[shortName] = msg.sender;

        emit RegisterShortName(msg.sender, shortName, nonce);
    }

    /**
     * Registers a short name for the avatar using a specific nonce if the short name is available
     * @param _nonce nonce to be used in the calculation
     */
    function registerShortNameWithNonce(uint256 _nonce) external {
        if (shortNames[msg.sender] != uint72(0)) {
            revert CirclesNamesShortNameAlreadyAssigned(msg.sender, shortNames[msg.sender], 0);
        }
        // require(hub.avatars(msg.sender) != address(0), "Avatar has not been registered in the hub.");

        uint72 shortName = calculateShortNameWithNonce(msg.sender, _nonce);

        if (addresses[shortName] != address(0)) {
            revert CirclesNamesShortNameWithNonceTaken(msg.sender, _nonce, shortName, addresses[shortName]);
        }

        // assign the name to the address
        shortNames[msg.sender] = shortName;
        // assign the address to the name
        addresses[shortName] = msg.sender;

        emit RegisterShortName(msg.sender, shortName, _nonce);
    }

    // Public functions

    /**
     * Search for the first available short name for the avatar and return the short name and nonce
     * @param _avatar address for which the name is to be calculated
     * @return shortName_ short name that can be assigned to the avatar
     * @return nonce_ nonce for which this name can be assigned
     */
    function searchShortName(address _avatar) public view returns (uint72 shortName_, uint256 nonce_) {
        if (shortNames[_avatar] != uint72(0)) {
            revert CirclesNamesShortNameAlreadyAssigned(_avatar, shortNames[_avatar], 0);
        }

        while (true) {
            shortName_ = calculateShortNameWithNonce(_avatar, nonce_);

            if (addresses[shortName_] == address(0)) {
                // if the name is not yet assigned, let's keep it
                break;
            }
            // if the name is already assigned, increment the nonce and try again
            nonce_++;
        }

        return (shortName_, nonce_);
    }

    /**
     * Calculates a short name for the avatar using a nonce
     * @param _avatar address for which the short name is to be calculated
     * @param _nonce nonce to be used in the calculation
     */
    function calculateShortNameWithNonce(address _avatar, uint256 _nonce) public pure returns (uint72 shortName_) {
        // use keccak256 to generate a pseudo-random number
        bytes32 digest = keccak256(abi.encodePacked(_avatar, _nonce));
        // take the modulo of the digest to get a number between 0 and MAX_NAME
        shortName_ = uint72(uint256(digest) % (MAX_SHORT_NAME + 1));
    }

    /**
     * @dev checks whether string is a valid name by checking
     * the length as max 32 bytes and the allowed characters: 0-9, A-Z, a-z, space,
     * hyphen, underscore, period, parentheses, apostrophe,
     * ampersand, plus and hash.
     * This restricts the contract name to a subset of ASCII characters,
     * and excludes unicode characters for other alphabets and emoticons.
     * Instead the default ERC1155 metadata read from the IPFS CID registry,
     * should provide the full display name with unicode characters.
     * Names are not checked for uniqueness.
     */
    function isValidName(string calldata _name) public pure returns (bool) {
        bytes memory nameBytes = bytes(_name);
        if (nameBytes.length > 32 || nameBytes.length == 0) return false; // Check length

        for (uint256 i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];
            if (
                !(char >= 0x30 && char <= 0x39) // 0-9
                    && !(char >= 0x41 && char <= 0x5A) // A-Z
                    && !(char >= 0x61 && char <= 0x7A) // a-z
                    && !(char == 0x20) // Space
                    && !(char == 0x2D || char == 0x5F) // Hyphen (-), Underscore (_)
                    && !(char == 0x2E) // Period (.)
                    && !(char == 0x28 || char == 0x29) // Parentheses ( () )
                    && !(char == 0x27) // Apostrophe (')
                    && !(char == 0x26) // Ampersand (&)
                    && !(char == 0x2B || char == 0x23) // Plus (+), Hash (#)
            ) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev checks whether string is a valid symbol by checking
     * the length as max 16 bytes and the allowed characters: 0-9, A-Z, a-z,
     * hyphen, underscore.
     */
    function isValidSymbol(string calldata _symbol) public pure returns (bool) {
        bytes memory symbolBytes = bytes(_symbol);
        if (symbolBytes.length == 0 || symbolBytes.length > 16) {
            return false; // Check length is within range
        }

        for (uint256 i = 0; i < symbolBytes.length; i++) {
            bytes1 char = symbolBytes[i];
            if (
                // allowed ASCII characters 0-9, A-Z, a-z, Hyphen (-), Underscore (_)
                !(
                    (char >= 0x30 && char <= 0x39) || (char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A)
                        || (char == 0x2D) || (char == 0x5F)
                )
            ) {
                return false;
            }
        }
        return true;
    }
}
