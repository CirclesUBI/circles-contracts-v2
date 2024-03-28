// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../errors/Errors.sol";
import "../hub/IHub.sol";
import "./Base58Converter.sol";

contract NameRegistry is Base58Converter, INameRegistryErrors, ICirclesErrors {
    // Constants

    /**
     * @notice The last ("biggest") short name that can be assigned is "zzzzzzzzzzzz",
     * which is 1449225352009601191935 in decimal when converted from base58
     */
    uint72 public constant MAX_SHORT_NAME = uint72(1449225352009601191935);

    /**
     * @notice The default name prefix for Circles
     * @dev to test pre-release codes, we use a toy name prefix
     * so that we can easily identify the test Circles
     */
    string public constant DEFAULT_CIRCLES_NAME_PREFIX = "Rings-";

    /**
     * @notice The default symbol for Circles
     */
    string public constant DEFAULT_CIRCLES_SYMBOL = "RING";

    // State variables

    /**
     * @notice The address of the hub contract where the address must have registered first
     */
    IHubV2 public hub;

    /**
     * @notice a mapping from the avatar address to the assigned name
     * @dev 9 bytes or uint72 fit 12 characters in base58 encoding
     */
    mapping(address => uint72) public shortNames;

    /**
     * @notice a mapping from the short name to the address
     */
    mapping(uint72 => address) public shortNameToAvatar;

    mapping(address => string) public customNames;

    mapping(address => string) public customSymbols;

    /**
     * @notice avatarToCidV0Digest is a mapping of avatar to the IPFS CIDv0 digest.
     */
    mapping(address => bytes32) public avatarToCidV0Digest;

    // Events

    event RegisterShortName(address indexed avatar, uint72 shortName, uint256 nonce);

    event CidV0(address indexed avatar, bytes32 cidV0Digest);

    // Modifiers

    modifier mustBeRegistered(address _avatar, uint8 _code) {
        if (hub.avatars(_avatar) == address(0)) {
            revert CirclesAvatarMustBeRegistered(_avatar, _code);
        }
        _;
    }

    modifier onlyHub(uint8 _code) {
        if (msg.sender != address(hub)) {
            revert CirclesInvalidFunctionCaller(msg.sender, address(hub), _code);
        }
        _;
    }

    // Constructor

    constructor(IHubV2 _hub) {
        if (address(_hub) == address(0)) {
            // Hub cannot be the zero address.
            revert CirclesAddressCannotBeZero(0);
        }
        hub = _hub;
    }

    // External functions

    /**
     * @notice Register a short name for the avatar
     */
    function registerShortName() external mustBeRegistered(msg.sender, 0) {
        (uint72 shortName, uint256 nonce) = searchShortName(msg.sender);

        // assign the name to the address
        shortNames[msg.sender] = shortName;
        // assign the address to the name
        shortNameToAvatar[shortName] = msg.sender;

        emit RegisterShortName(msg.sender, shortName, nonce);
    }

    /**
     * Registers a short name for the avatar using a specific nonce if the short name is available
     * @param _nonce nonce to be used in the calculation
     */
    function registerShortNameWithNonce(uint256 _nonce) external mustBeRegistered(msg.sender, 1) {
        if (shortNames[msg.sender] != uint72(0)) {
            revert CirclesNamesShortNameAlreadyAssigned(msg.sender, shortNames[msg.sender], 0);
        }

        uint72 shortName = calculateShortNameWithNonce(msg.sender, _nonce);

        if (shortNameToAvatar[shortName] != address(0)) {
            revert CirclesNamesShortNameWithNonceTaken(msg.sender, _nonce, shortName, shortNameToAvatar[shortName]);
        }

        // assign the name to the address
        shortNames[msg.sender] = shortName;
        // assign the address to the name
        shortNameToAvatar[shortName] = msg.sender;

        emit RegisterShortName(msg.sender, shortName, _nonce);
    }

    function updateCidV0Digest(address _avatar, bytes32 _cidV0Digest) external onlyHub(0) {
        avatarToCidV0Digest[_avatar] = _cidV0Digest;

        emit CidV0(_avatar, _cidV0Digest);
    }

    function registerCustomName(address _avatar, string calldata _name) external onlyHub(1) {
        if (bytes(_name).length == 0) {
            // if name is left empty, it will default to default name "Circles-<base58(short)Name>"
            return;
        }
        if (!isValidName(_name)) {
            revert CirclesNamesInvalidName(_avatar, _name, 0);
        }
        customNames[_avatar] = _name;
    }

    function registerCustomSymbol(address _avatar, string calldata _symbol) external onlyHub(2) {
        if (bytes(_symbol).length == 0) {
            // if symbol is left empty, it will default to default symbol "CRC"
            return;
        }
        if (!isValidSymbol(_symbol)) {
            revert CirclesNamesInvalidName(_avatar, _symbol, 1);
        }
        customSymbols[_avatar] = _symbol;
    }

    function name(address _avatar) external view mustBeRegistered(_avatar, 1) returns (string memory) {
        if (!hub.isHuman(_avatar)) {
            // groups and organizations can have set a custom name
            string memory customName = customNames[_avatar];
            if (bytes(customName).length > 0) {
                // if it has a custom name, use it
                return customName;
            }
            // otherwise, use the default name for groups and organizations
        }
        // for personal Circles use default name
        uint72 shortName = shortNames[_avatar];
        if (shortName == uint72(0)) {
            string memory base58FullAddress = toBase58(uint256(uint160(_avatar)));
            return string(abi.encodePacked("DEFAULT_CIRCLES_NAME_PREFIX", base58FullAddress));
        }
        string memory base58ShortName = toBase58(uint256(shortName));
        return string(abi.encodePacked("DEFAULT_CIRCLES_NAME_PREFIX", base58ShortName));
    }

    function symbol(address _avatar) external view mustBeRegistered(_avatar, 2) returns (string memory) {
        if (hub.isOrganization(_avatar)) {
            revert CirclesNamesOrganizationHasNoSymbol(_avatar, 0);
        }
        if (hub.isGroup(_avatar)) {
            // groups can have set a custom symbol
            string memory customSymbol = customSymbols[_avatar];
            if (bytes(customSymbol).length > 0) {
                // if it has a custom symbol, use it
                return customSymbol;
            }
            // otherwise, use the default symbol for groups
        }
        // for all personal Circles use default symbol
        return DEFAULT_CIRCLES_SYMBOL;
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

            if (shortNameToAvatar[shortName_] == address(0)) {
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
