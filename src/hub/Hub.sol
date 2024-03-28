// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

// import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/utils/Create2.sol";
import "../circles/Circles.sol";
import "../errors/Errors.sol";
import "../groups/IMintPolicy.sol";
import "../lift/IERC20Lift.sol";
import "../migration/IHub.sol";
import "../migration/IToken.sol";
import "../names/INameRegistry.sol";
import "./MetadataDefinitions.sol";

/**
 * @title Hub v2 contract for Circles
 * @notice The Hub contract is the main contract for the Circles protocol.
 * It adopts the ERC1155 standard for multi-token contracts and governs
 * the personal and group Circles of people, organizations and groups.
 * Circle balances are demurraged in the Hub contract.
 * It registers the trust relations between people and groups and allows
 * to transfer Circles to be path fungible along trust relations.
 * It further allows to wrap any token into an inflationary or demurraged
 * ERC20 Circles contract.
 */
contract Hub is Circles, MetadataDefinitions, IHubErrors, ICirclesErrors {
    // Type declarations

    /**
     * @notice TrustMarker stores the expiry of a trust relation as uint96,
     * and is iterable as a linked list of trust markers.
     * @dev This is used to store the directional trust relation between two avatars,
     * and the expiry of the trust relation as uint96 in unix time.
     */
    struct TrustMarker {
        address previous;
        uint96 expiry;
    }

    struct FlowEdge {
        uint16 streamSinkId;
        uint240 amount; // todo: set this to uint192 (align with demurrage), and leave it to compiler to pad
    }

    struct Stream {
        uint16 sourceCoordinate;
        uint16[] flowEdgeIds; // todo: this can possible be packed more compactly manually, evaluate
        bytes data;
    }

    // Constants

    /**
     * @dev Welcome bonus for new avatars invited to Circles. Set to 50 Circles.
     */
    uint256 private constant WELCOME_BONUS = 50 * EXA;

    /**
     * @dev The cost of an invitation for a new avatar, paid in personal Circles burnt, set to 100 Circles.
     */
    uint256 private constant INVITATION_COST = 2 * WELCOME_BONUS;

    /**
     * @dev The address used as the first element of the linked list of avatars.
     */
    address private constant SENTINEL = address(0x1);

    // State variables

    /**
     * @notice The Hub v1 contract address.
     */
    IHubV1 public immutable hubV1;

    /**
     * @notice The name registry contract address.
     */
    INameRegistry public nameRegistry;

    /**
     * @notice The address of the migration contract for v1 Circles.
     */
    address public migration;

    /**
     * @notice The address of the Lift ERC20 contract.
     */
    IERC20Lift public liftERC20;

    /**
     * @notice The timestamp of the start of the invitation-only period.
     * @dev This is used to determine the start of the invitation-only period.
     * Prior to this time v1 avatars can register without an invitation, and
     * new avatars can be invited by registered avatars. After this time
     * only registered avatars can invite new avatars.
     */
    uint256 public immutable invitationOnlyTime;

    /**
     * @notice The standard treasury contract address used when
     * registering a (non-custom) group.
     */
    address public standardTreasury;

    /**
     * @notice The mapping of registered avatar addresses to the next avatar address,
     * stored as a linked list.
     * @dev This is used to store the linked list of registered avatars.
     */
    mapping(address => address) public avatars;

    /**
     * @notice The mapping of group avatar addresses to the mint policy contract address.
     */
    mapping(address => address) public mintPolicies;

    /**
     * @notice The mapping of group avatar addresses to the treasury contract address.
     */
    mapping(address => address) public treasuries;

    /**
     * @notice The iterable mapping of directional trust relations between avatars and
     * their expiry times.
     */
    mapping(address => mapping(address => TrustMarker)) public trustMarkers;

    // Events

    event RegisterHuman(address indexed avatar);
    event InviteHuman(address indexed inviter, address indexed invited);
    event RegisterOrganization(address indexed organization, string name);
    event RegisterGroup(
        address indexed group, address indexed mint, address indexed treasury, string name, string symbol
    );

    event Trust(address indexed truster, address indexed trustee, uint256 expiryTime);

    event Stopped(address indexed avatar);

    // Modifiers

    /**
     * Modifier to check if the current time is during the bootstrap period.
     */
    modifier onlyDuringBootstrap(uint8 _code) {
        if (block.timestamp > invitationOnlyTime) {
            revert CirclesHubOnlyDuringBootstrap(_code);
        }
        _;
    }

    /**
     * Modifier to check if the caller is the migration contract.
     */
    modifier onlyMigration() {
        if (msg.sender != migration) {
            revert CirclesInvalidFunctionCaller(msg.sender, migration, 0);
        }
        _;
    }

    // Constructor

    /**
     * @notice Constructor for the Hub contract.
     * @param _hubV1 address of the Hub v1 contract
     * @param _inflationDayZero timestamp of the start of the global inflation curve.
     * For deployment on Gnosis Chain this parameter should be set to midnight 15 October 2020,
     * or in unix time 1602786330 (deployment at 6:25:30 pm UTC) - 66330 (offset to midnight) = 1602720000.
     * @param _standardTreasury address of the standard treasury contract
     * @param _bootstrapTime duration of the bootstrap period (for v1 registration) in seconds
     * @param _fallbackUri fallback URI string for the ERC1155 metadata,
     * (todo: eg. "https://fallback.aboutcircles.com/v1/circles/{id}.json")
     */
    constructor(
        IHubV1 _hubV1,
        INameRegistry _nameRegistry,
        address _migration,
        IERC20Lift _liftERC20,
        address _standardTreasury,
        uint256 _inflationDayZero,
        uint256 _bootstrapTime,
        string memory _fallbackUri
    ) Circles(_inflationDayZero, _fallbackUri) {
        if (address(_hubV1) == address(0)) {
            revert CirclesAddressCannotBeZero(0);
        }
        if (_standardTreasury == address(0)) {
            revert CirclesAddressCannotBeZero(1);
        }

        // initialize linked list for avatars
        avatars[SENTINEL] = SENTINEL;

        // store the Hub v1 contract address
        hubV1 = _hubV1;

        // store the name registry contract address
        nameRegistry = _nameRegistry;

        // store the migration contract address
        migration = _migration;

        // store the lift ERC20 contract address
        liftERC20 = _liftERC20;

        // store the standard treasury contract address for registerGroup()
        standardTreasury = _standardTreasury;

        // invitation-only period starts after the bootstrap time has passed since deployment
        invitationOnlyTime = block.timestamp + _bootstrapTime;
    }

    // External functions

    /**
     * @notice Register human allows to register an avatar for a human,
     * if they have a stopped v1 Circles contract, during the bootstrap period.
     * @param _cidV0Digest (optional) IPFS CIDv0 digest for the avatar metadata
     * should follow ERC1155 metadata standard.
     */
    function registerHuman(bytes32 _cidV0Digest) external onlyDuringBootstrap(0) {
        // only available for v1 users with stopped v1 mint, for initial bootstrap period
        address v1CirclesStatus = _registerHuman(msg.sender);
        if (v1CirclesStatus != CIRCLES_STOPPED_V1) {
            revert CirclesHubRegisterAvatarV1MustBeStopped(msg.sender, 0);
        }

        // store the IPFS CIDv0 digest for the avatar metadata
        nameRegistry.updateCidV0Digest(msg.sender, _cidV0Digest);

        emit RegisterHuman(msg.sender);
    }

    /**
     * @notice Invite human allows to register another human avatar.
     * The inviter must burn twice the welcome bonus of their own Circles,
     * and the invited human receives the welcome bonus in their personal Circles.
     * The inviter is set to trust the invited avatar.
     * @param _human avatar of the human to invite
     */
    function inviteHuman(address _human) external {
        if (!isHuman(msg.sender)) {
            revert CirclesHubMustBeHuman(msg.sender, 0);
        }

        // register the invited human; reverts if they already exist
        _registerHuman(_human);

        if (block.timestamp > invitationOnlyTime) {
            // after the bootstrap period, the inviter must burn the invitation cost
            _burn(msg.sender, toTokenId(msg.sender), INVITATION_COST);

            // todo: re-discuss desired approach to welcome bonus vs migration
            // invited receives the welcome bonus in their personal Circles
            _mint(_human, toTokenId(_human), WELCOME_BONUS, "");
        }

        // set trust to indefinite future, but avatar can edit this later
        _trust(msg.sender, _human, INDEFINITE_FUTURE);

        emit InviteHuman(msg.sender, _human);
    }

    /**
     * @notice Register group allows to register a group avatar.
     * @param _mint mint address will be called before minting group circles
     * @param _name immutable name of the group Circles
     * @param _symbol immutable symbol of the group Circles
     * @param _cidV0Digest IPFS CIDv0 digest for the group metadata
     */
    function registerGroup(address _mint, string calldata _name, string calldata _symbol, bytes32 _cidV0Digest)
        external
    {
        _registerGroup(msg.sender, _mint, standardTreasury, _name, _symbol);

        // for groups register possible custom name and symbol
        nameRegistry.registerName(msg.sender, _name);
        nameRegistry.registerSymbol(msg.sender, _symbol);

        // store the IPFS CIDv0 digest for the group metadata
        nameRegistry.updateCidV0Digest(msg.sender, _cidV0Digest);

        emit RegisterGroup(msg.sender, _mint, standardTreasury, _name, _symbol);
    }

    /**
     * @notice Register custom group allows to register a group with a custom treasury contract.
     * @param _mint mint address will be called before minting group circles
     * @param _treasury treasury address for receiving collateral
     * @param _name immutable name of the group Circles
     * @param _symbol immutable symbol of the group Circles
     * @param _cidV0Digest IPFS CIDv0 digest for the group metadata
     */
    function registerCustomGroup(
        address _mint,
        address _treasury,
        string calldata _name,
        string calldata _symbol,
        bytes32 _cidV0Digest
    ) external {
        _registerGroup(msg.sender, _mint, _treasury, _name, _symbol);

        // for groups register possible custom name and symbol
        nameRegistry.registerName(msg.sender, _name);
        nameRegistry.registerSymbol(msg.sender, _symbol);

        // store the IPFS CIDv0 digest for the group metadata
        nameRegistry.updateCidV0Digest(msg.sender, _cidV0Digest);

        emit RegisterGroup(msg.sender, _mint, _treasury, _name, _symbol);
    }

    /**
     * @notice Register organization allows to register an organization avatar.
     * @param _name name of the organization
     * @param _cidV0Digest IPFS CIDv0 digest for the organization metadata
     */
    function registerOrganization(string calldata _name, bytes32 _cidV0Digest) external {
        _insertAvatar(msg.sender);

        // for organizations, only register possible custom name
        nameRegistry.registerName(msg.sender, _name);

        // store the IPFS CIDv0 digest for the organization metadata
        nameRegistry.updateCidV0Digest(msg.sender, _cidV0Digest);

        emit RegisterOrganization(msg.sender, _name);
    }

    /**
     * @notice Trust allows to trust another address for a certain period of time.
     * Expiry times in the past are set to the current block timestamp.
     * @param _trustReceiver address that is trusted by the caller
     * @param _expiry expiry time in seconds since unix epoch until when trust is valid
     * @dev Trust is directional and can be set by the caller to any address.
     * The trusted address does not (yet) have to be registered in the Hub contract.
     */
    function trust(address _trustReceiver, uint96 _expiry) external {
        if (avatars[msg.sender] == address(0)) {
            revert CirclesAvatarMustBeRegistered(msg.sender, 0);
        }
        if (_trustReceiver == address(0) || _trustReceiver == SENTINEL) {
            // You cannot trust the zero address or the sentinel address.
            // Reserved addresses for logic.
            revert CirclesHubInvalidTrustReceiver(_trustReceiver, 0);
        }
        if (_trustReceiver == msg.sender) {
            // You cannot edit your own trust relation.
            revert CirclesHubInvalidTrustReceiver(_trustReceiver, 1);
        }
        // expiring trust cannot be set in the past
        if (_expiry < block.timestamp) _expiry = uint96(block.timestamp);
        _trust(msg.sender, _trustReceiver, _expiry);
    }

    /**
     * @notice Personal mint allows to mint personal Circles for a registered human avatar.
     */
    function personalMint() external {
        if (!isHuman(msg.sender)) {
            // Only avatars registered as human can call personal mint.
            revert CirclesHubMustBeHuman(msg.sender, 1);
        }
        // check if v1 Circles is known to be stopped and update status
        _checkHumanV1CirclesStatus(msg.sender);

        // claim issuance if any is available
        _claimIssuance(msg.sender);
    }

    /**
     * @notice Calculate issuance allows to calculate the issuance for a human avatar with a check
     * to update the v1 mint status if updated.
     * @param _human address of the human avatar to calculate the issuance for
     * @return issuance amount of Circles that can be minted
     * @return startPeriod start of the claimable period
     * @return endPeriod end of the claimable period
     */
    function calculateIssuanceWithCheck(address _human) external returns (uint256, uint256, uint256) {
        // check if v1 Circles is known to be stopped and update status
        _checkHumanV1CirclesStatus(_human);
        // calculate issuance for the human avatar, but don't mint
        return calculateIssuance(_human);
    }

    /**
     * @notice Group mint allows to mint group Circles by providing the required collateral.
     * @param _group address of the group avatar to mint Circles of
     * @param _collateralAvatars array of (personal or group) avatar addresses to be used as collateral
     * @param _amounts array of amounts of collateral to be used for minting
     * @param _data (optional) additional data to be passed to the mint policy, treasury and minter
     */
    function groupMint(
        address _group,
        address[] calldata _collateralAvatars,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external {
        uint256[] memory collateral = new uint256[](_collateralAvatars.length);
        for (uint256 i = 0; i < _collateralAvatars.length; i++) {
            collateral[i] = toTokenId(_collateralAvatars[i]);
        }
        _groupMint(msg.sender, _group, collateral, _amounts, _data);
    }

    /**
     * @notice Stop allows to stop future mints of personal Circles for this avatar.
     * Must be called by the avatar itself. This action is irreversible.
     */
    function stop() external {
        if (!isHuman(msg.sender)) {
            // Only human can call stop.
            revert CirclesHubMustBeHuman(msg.sender, 2);
        }
        MintTime storage mintTime = mintTimes[msg.sender];
        // check if already stopped
        if (mintTime.lastMintTime == INDEFINITE_FUTURE) {
            return;
        }
        // stop future mints of personal Circles
        // by setting the last mint time to indefinite future.
        mintTime.lastMintTime = INDEFINITE_FUTURE;

        emit Stopped(msg.sender);
    }

    /**
     * Stopped checks whether the avatar has stopped future mints of personal Circles.
     * @param _human address of avatar of the human to check whether it is stopped
     */
    function stopped(address _human) external view returns (bool) {
        if (!isHuman(_human)) {
            // Only personal Circles can have a status of boolean stopped.
            revert CirclesHubMustBeHuman(_human, 3);
        }
        MintTime storage mintTime = mintTimes[msg.sender];
        return (mintTime.lastMintTime == INDEFINITE_FUTURE);
    }

    /**
     * @notice Migrate allows to migrate v1 Circles to v2 Circles. During bootstrap period,
     * no invitation cost needs to be paid for new humans to be registered. After the bootstrap
     * period the same invitation cost applies as for normal invitations, and this requires the
     * owner to be a human and to have enough personal Circles to pay the invitation cost.
     * Organizations and groups have to ensure all humans have been registered after the bootstrap period.
     * Can only be called by the migration contract.
     * @param _owner address of the owner of the v1 Circles and beneficiary of the v2 Circles
     * @param _avatars array of avatar addresses to migrate
     * @param _amounts array of amounts in inflationary v1 units to migrate
     */
    function migrate(address _owner, address[] calldata _avatars, uint256[] calldata _amounts) external onlyMigration {
        if (avatars[_owner] == address(0)) {
            // Only registered avatars can migrate v1 tokens.
            revert CirclesAvatarMustBeRegistered(_owner, 1);
        }
        if (_avatars.length != _amounts.length) {
            revert CirclesArraysLengthMismatch(_avatars.length, _amounts.length, 0);
        }

        // register all unregistered avatars as humans, and check that registered avatars are humans
        // after the bootstrap period, the _owner needs to pay the equivalent invitation cost for all newly registered humans
        uint256 cost = INVITATION_COST * _ensureAvatarsRegistered(_avatars);

        // Invitation cost only applies after the bootstrap period
        if (block.timestamp > invitationOnlyTime && cost > 0) {
            // personal Circles are required to burn the invitation cost
            if (!isHuman(_owner)) {
                // Only humans can migrate v1 tokens after the bootstrap period.
                revert CirclesHubMustBeHuman(_owner, 4);
            }
            _burn(_owner, toTokenId(_owner), cost);
        }

        for (uint256 i = 0; i < _avatars.length; i++) {
            // mint the migrated balances to _owner
            _mint(_owner, toTokenId(_avatars[i]), _amounts[i], "");
        }
    }

    /**
     * @notice Burn allows to burn Circles owned by the caller.
     * @param _id Circles identifier of the Circles to burn
     * @param _amount amount of Circles to burn
     * @param _data (optional) additional data to be passed to the burn policy if they are group Circles
     */
    function burn(uint256 _id, uint256 _amount, bytes calldata _data) external {
        // note: by construction we can not have an id with non-zero balance,
        // that was not converted from a group address.
        // Nonetheless assert that the id is identical an address
        address group = _validateAddressFromId(_id, 0);

        IMintPolicy policy = IMintPolicy(mintPolicies[group]);
        if (address(policy) != address(0) && treasuries[group] != msg.sender) {
            // if Circles are a group Circles and if the burner is not the associated treasury,
            // then the mint policy must approve the burn
            if (!policy.beforeBurnPolicy(msg.sender, group, _amount, _data)) {
                // Burn policy rejected burn.
                revert CirclesHubGroupMintPolicyRejectedBurn(msg.sender, group, _amount, _data, 0);
            }
        }
        _burn(msg.sender, _id, _amount);
    }

    // Public functions

    function wrap(address _avatar, uint256 _amount, CirclesType _type) public {
        if (!isHuman(_avatar) && !isGroup(_avatar)) {
            // Avatar must be human or group.
            revert CirclesAvatarMustBeRegistered(_avatar, 2);
        }
        address erc20Wrapper = liftERC20.ensureERC20(_avatar, _type);
        safeTransferFrom(msg.sender, erc20Wrapper, toTokenId(_avatar), _amount, "");
    }

    // todo: if we have space, possibly have a wrapBatch function

    // function getDeterministicAddress(uint256 _tokenId, bytes32 _bytecodeHash) public view returns (address) {
    //     return Create2.computeAddress(keccak256(abi.encodePacked(_tokenId)), _bytecodeHash);
    // }

    // function createERC20InflationWrapper(uint256 _tokenId, string memory _name, string memory _symbol) public {
    //     require(address(tokenIDToInfERC20[_tokenId]) == address(0), "Wrapper already exists");

    //     bytes memory bytecode =
    //         abi.encodePacked(type(WrappedERC20).creationCode, abi.encode(_name, _symbol, address(this), _tokenId));

    //     //bytes32 bytecodeHash = keccak256(bytecode);
    //     address wrappedToken = Create2.deploy(0, keccak256(abi.encodePacked(_tokenId)), bytecode);

    //     tokenIDToInfERC20[_tokenId] = WrappedERC20(wrappedToken);
    // }

    // function wrapInflationaryERC20(uint256 _tokenId, uint256 _amount) public {
    //     require(address(tokenIDToInfERC20[_tokenId]) != address(0), "Wrapper does not exist");
    //     safeTransferFrom(msg.sender, address(tokenIDToInfERC20[_tokenId]), _tokenId, _amount, "");
    //     tokenIDToInfERC20[_tokenId].mint(msg.sender, _amount);
    // }

    // function unwrapInflationaryERC20(uint256 _tokenId, uint256 _amount) public {
    //     require(address(tokenIDToInfERC20[_tokenId]) != address(0), "Wrapper does not exist");
    //     tokenIDToInfERC20[_tokenId].burn(msg.sender, _amount);
    //     safeTransferFrom(address(tokenIDToInfERC20[_tokenId]), msg.sender, _tokenId, _amount, "");
    // }

    function operateFlowMatrix(
        address[] calldata _flowVertices,
        FlowEdge[] calldata _flow,
        Stream[] calldata _streams,
        bytes calldata _packedCoordinates
    ) external {
        // first unpack the coordinates to array of uint16
        uint16[] memory coordinates = _unpackCoordinates(_packedCoordinates, _flow.length);

        // check all senders have the operator authorized
        for (uint16 i = 0; i < _streams.length; i++) {
            if (!isApprovedForAll(_flowVertices[_streams[i].sourceCoordinate], msg.sender)) {
                // Operator not approved for source.
                revert CirclesHubOperatorNotApprovedForSource(
                    msg.sender, _flowVertices[_streams[i].sourceCoordinate], i, 0
                );
            }
        }

        // if no streams are provided, then only closed paths are allowed
        bool closedPath = (_streams.length == 0);

        // verify the correctness of the flow matrix describing the path itself,
        // ie. well-definedness of the flow matrix itself,
        // check all entities are registered, and the trust relations are respected.
        int256[] memory matrixNettedFlow = _verifyFlowMatrix(_flowVertices, _flow, coordinates, closedPath);

        _effectPathTransfers(_flowVertices, _flow, _streams, coordinates);

        int256[] memory streamsNettedFlow = _callAcceptanceChecks(_flowVertices, _flow, _streams, coordinates);

        _matchNettedFlows(streamsNettedFlow, matrixNettedFlow);
    }

    // Public functions

    /**
     * Checks if an avatar is registered as a human.
     * @param _human address of the human to check
     */
    function isHuman(address _human) public view returns (bool) {
        return mintTimes[_human].lastMintTime > 0;
    }

    /**
     * Checks if an avatar is registered as a group.
     * @param _group address of the group to check
     */
    function isGroup(address _group) public view returns (bool) {
        return mintPolicies[_group] != address(0);
    }

    /**
     * @notice Checks if an avatar is registered as an organization.
     * @param _organization address of the organization to check
     */
    function isOrganization(address _organization) public view returns (bool) {
        return avatars[_organization] != address(0) && mintPolicies[_organization] == address(0)
            && mintTimes[_organization].lastMintTime == uint256(0);
    }

    /**
     * @notice Returns true if the truster trusts the trustee.
     * @param _truster Address of the trusting account
     * @param _trustee Address of the trusted account
     */
    function isTrusted(address _truster, address _trustee) public view returns (bool) {
        // trust up until expiry timestamp
        return uint256(trustMarkers[_truster][_trustee].expiry) >= block.timestamp;
    }

    /**
     * uri returns the IPFS URI for the ERC1155 token.
     * If the
     * @param _id tokenId of the ERC1155 token
     */
    function uri(uint256 _id) public view override returns (string memory uri_) {
        // todo: should fallback move into SDK rather than contract ?
        // todo: we don't need to override this function if we keep this pattern
        // "https://fallback.aboutcircles.com/v1/profile/{id}.json"
        return super.uri(_id);
    }

    // /**
    //  * @dev checks whether string is a valid name by checking
    //  * the length as max 32 bytes and the allowed characters: 0-9, A-Z, a-z, space,
    //  * hyphen, underscore, period, parentheses, apostrophe,
    //  * ampersand, plus and hash.
    //  * This restricts the contract name to a subset of ASCII characters,
    //  * and excludes unicode characters for other alphabets and emoticons.
    //  * Instead the default ERC1155 metadata read from the IPFS CID registry,
    //  * should provide the full display name with unicode characters.
    //  * Names are not checked for uniqueness.
    //  */
    // function isValidName(string memory _name) public pure returns (bool) {
    //     bytes memory nameBytes = bytes(_name);
    //     if (nameBytes.length > 32 || nameBytes.length == 0) return false; // Check length

    //     for (uint256 i = 0; i < nameBytes.length; i++) {
    //         bytes1 char = nameBytes[i];
    //         if (
    //             !(char >= 0x30 && char <= 0x39) // 0-9
    //                 && !(char >= 0x41 && char <= 0x5A) // A-Z
    //                 && !(char >= 0x61 && char <= 0x7A) // a-z
    //                 && !(char == 0x20) // Space
    //                 && !(char == 0x2D || char == 0x5F) // Hyphen (-), Underscore (_)
    //                 && !(char == 0x2E) // Period (.)
    //                 && !(char == 0x28 || char == 0x29) // Parentheses ( () )
    //                 && !(char == 0x27) // Apostrophe (')
    //                 && !(char == 0x26) // Ampersand (&)
    //                 && !(char == 0x2B || char == 0x23) // Plus (+), Hash (#)
    //         ) {
    //             return false;
    //         }
    //     }
    //     return true;
    // }

    // /**
    //  * @dev checks whether string is a valid symbol by checking
    //  * the length as max 16 bytes and the allowed characters: 0-9, A-Z, a-z,
    //  * hyphen, underscore.
    //  */
    // function isValidSymbol(string memory _symbol) public pure returns (bool) {
    //     bytes memory symbolBytes = bytes(_symbol);
    //     if (symbolBytes.length == 0 || symbolBytes.length > 16) {
    //         return false; // Check length is within range
    //     }

    //     for (uint256 i = 0; i < symbolBytes.length; i++) {
    //         bytes1 char = symbolBytes[i];
    //         if (
    //             // allowed ASCII characters 0-9, A-Z, a-z, Hyphen (-), Underscore (_)
    //             !(
    //                 (char >= 0x30 && char <= 0x39) || (char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A)
    //                     || (char == 0x2D) || (char == 0x5F)
    //             )
    //         ) {
    //             return false;
    //         }
    //     }
    //     return true;
    // }

    // Internal functions

    /**
     * @notice Group mint allows to mint group Circles by providing the required collateral.
     * @param _sender address of the sender of the group mint, and receiver of minted group Circles
     * @param _group address of the group avatar to mint Circles of
     * @param _collateral array of (personal or group) avatar addresses to be used as collateral
     * @param _amounts array of amounts of collateral to be used for minting
     * @param _data (optional) additional data to be passed to the mint policy, treasury and minter
     */
    function _groupMint(
        address _sender,
        address _group,
        uint256[] memory _collateral,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal {
        if (_collateral.length != _amounts.length) {
            // Collateral and amount arrays must have equal length.
            revert CirclesArraysLengthMismatch(_collateral.length, _amounts.length, 1);
        }
        if (_collateral.length == 0) {
            // At least one collateral must be provided.
            revert CirclesArrayMustNotBeEmpty(0);
        }
        if (!isGroup(_group)) {
            // Group is not registered as an avatar.
            revert CirclesHubGroupIsNotRegistered(_group, 0);
        }

        // note: we don't need to check whether collateral circle ids are registered,
        // because only for registered collateral do non-zero balances exist to transfer,
        // so it suffices to check that all amounts are non-zero during summing.
        uint256 sumAmounts = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            // _groupMint is only called from the public groupMint function,
            // or from operateFlowMatrix, and both ensure the collateral ids are derived
            // from an address, so we can cast here without checks.
            if (!isTrusted(_group, address(uint160(_collateral[i])))) {
                // Group does not trust collateral.
                revert CirclesHubCirclesAreNotTrustedByReceiver(_group, _collateral[i], 0);
            }

            if (_amounts[i] == 0) {
                // Non-zero collateral must be provided.
                revert CirclesAmountMustNotBeZero(0);
            }
            sumAmounts += _amounts[i];
        }

        // Rely on the mint policy to determine whether the collateral is valid for minting
        if (!IMintPolicy(mintPolicies[_group]).beforeMintPolicy(_sender, _group, _collateral, _amounts, _data)) {
            // Mint policy rejected mint.
            revert CirclesHubGroupMintPolicyRejectedMint(_sender, _group, _collateral, _amounts, _data, 0);
        }

        // abi encode the group address into the data to send onwards to the treasury
        bytes memory metadataGroup = abi.encode(GroupMintMetadata({group: _group}));
        bytes memory dataWithGroup = abi.encode(
            Metadata({metadataType: METADATATYPE_GROUPMINT, metadata: metadataGroup, erc1155UserData: _data})
        );

        // note: treasury.on1155Received must implement and unpack the GroupMintMetadata to know the group
        safeBatchTransferFrom(_sender, treasuries[_group], _collateral, _amounts, dataWithGroup);

        // mint group Circles to the sender and send the original _data onwards
        _mint(_sender, toTokenId(_group), sumAmounts, _data);
    }

    function _verifyFlowMatrix(
        address[] calldata _flowVertices,
        FlowEdge[] calldata _flow,
        uint16[] memory _coordinates,
        bool _closedPath
    ) internal view returns (int256[] memory) {
        if (3 * _flow.length != _coordinates.length) {
            // Mismatch in flow and coordinates length.
            revert CirclesArraysLengthMismatch(_flow.length, _coordinates.length, 2);
        }
        if (_flowVertices.length > type(uint16).max) {
            // Too many vertices.
            revert CirclesArraysLengthMismatch(_flowVertices.length, type(uint16).max, 3);
        }
        if (_flowVertices.length == 0 || _flow.length == 0) {
            // Empty flow matrix
            revert CirclesArraysLengthMismatch(_flowVertices.length, _flow.length, 4);
        }

        // initialize the netted flow array
        int256[] memory nettedFlow = new int256[](_flowVertices.length);

        {
            // check all vertices are valid avatars, groups or organizations
            for (uint64 i = 0; i < _flowVertices.length - 1; i++) {
                if (uint160(_flowVertices[i]) >= uint160(_flowVertices[i + 1])) {
                    // Flow vertices must be in ascending order.
                    revert CirclesHubFlowVerticesMustBeSorted();
                }
                if (avatars[_flowVertices[i]] == address(0)) {
                    // Avatar must be registered.
                    revert CirclesAvatarMustBeRegistered(_flowVertices[i], 4);
                }
            }

            address lastAvatar = _flowVertices[_flowVertices.length - 1];
            if (avatars[lastAvatar] == address(0)) {
                // Avatar must be registered.
                revert CirclesAvatarMustBeRegistered(lastAvatar, 5);
            }
        }

        {
            // iterate over the coordinate index
            uint16 index = uint16(0);

            for (uint64 i = 0; i < _flow.length; i++) {
                // index: coordinate of Circles identifier avatar address
                // index + 1: sender coordinate
                // index + 2: receiver coordinate
                address circlesId = _flowVertices[_coordinates[index]];
                address to = _flowVertices[_coordinates[index + 2]];
                int256 flow = int256(uint256(_flow[i].amount));

                // check the receiver trusts the Circles being sent
                if (!isTrusted(to, circlesId)) {
                    // Receiver does not trust Circles being sent
                    revert CirclesHubCirclesAreNotTrustedByReceiver(to, toTokenId(circlesId), 1);
                }
                if (_closedPath && (to != circlesId || isGroup(circlesId))) {
                    // Closed paths can only return personal Circles to source.
                    revert CirclesHubOnClosedPathOnlyPersonalCirclesCanReturnToAvatar(to, toTokenId(circlesId));
                }

                // nett the flow, dividing out the different Circle identifiers
                // expect for all edges to a group, as they are interpreted
                // as a request for group mint in _effectPathTransfers
                if (!isGroup(to)) {
                    nettedFlow[_coordinates[index + 1]] -= flow;
                    nettedFlow[_coordinates[index + 2]] += flow;
                }
                index = index + 3;
            }
        }

        return nettedFlow;
    }

    function _effectPathTransfers(
        address[] calldata _flowVertices,
        FlowEdge[] calldata _flow,
        Stream[] calldata _streams,
        uint16[] memory _coordinates
    ) internal {
        // Create a counter to track the proper definition of the streams
        uint16[] memory streamBatchCounter = new uint16[](_streams.length);
        address[] memory streamReceivers = new address[](_streams.length);

        {
            // iterate over the coordinate index
            uint16 index = uint16(0);

            for (uint16 i = 0; i < _flow.length; i++) {
                // index: coordinate of Circles identifier avatar address
                // index + 1: sender coordinate
                // index + 2: receiver coordinate
                address to = _flowVertices[_coordinates[index + 2]];

                (uint256[] memory ids, uint256[] memory amounts) =
                    _asSingletonArrays(toTokenId(_flowVertices[_coordinates[index]]), uint256(_flow[i].amount));

                // Check that each stream has listed the actual terminal flow edges in the correct order.
                // Note, we can't do this check in _verifyFlowMatrix, because we run out of stack depth there.
                // streamSinkId starts counting from 1, so that 0 is reserved for non-terminal flow edges.
                if (_flow[i].streamSinkId > 0) {
                    uint16 streamSinkArrayId = _flow[i].streamSinkId - 1;
                    if (_streams[streamSinkArrayId].flowEdgeIds[streamBatchCounter[streamSinkArrayId]] != i) {
                        // Invalid stream sink
                        revert CirclesHubFlowEdgeStreamMismatch(i, _flow[i].streamSinkId, 0);
                    }
                    streamBatchCounter[streamSinkArrayId]++;
                    if (streamReceivers[streamSinkArrayId] == address(0)) {
                        streamReceivers[streamSinkArrayId] = to;
                    } else {
                        if (streamReceivers[streamSinkArrayId] != to) {
                            // Invalid stream receiver
                            revert CirclesHubFlowEdgeStreamMismatch(i, _flow[i].streamSinkId, 1);
                        }
                    }
                }

                // effect the flow edge
                if (!isGroup(to)) {
                    // do a erc1155 single transfer without acceptance check,
                    // as only nett receivers will get an acceptance call
                    _update(
                        _flowVertices[_coordinates[index + 1]], // sender, from coordinate
                        to,
                        ids,
                        amounts
                    );
                } else {
                    // do group mint, and the sender receives the minted group Circles
                    _groupMint(
                        _flowVertices[_coordinates[index + 1]], // sender, from coordinate
                        to, // group
                        ids, // collateral
                        amounts, // amounts
                        ""
                    );
                }

                index = index + 3;
            }

            // check that all streams are properly defined
            for (uint16 i = 0; i < _streams.length; i++) {
                if (streamReceivers[i] == address(0)) {
                    // Invalid stream receiver
                    revert CirclesHubStreamMismatch(i, 0);
                }
                if (streamBatchCounter[i] != _streams[i].flowEdgeIds.length) {
                    // Invalid stream batch
                    revert CirclesHubStreamMismatch(i, 1);
                }
            }
        }
    }

    function _callAcceptanceChecks(
        address[] calldata _flowVertices,
        FlowEdge[] calldata _flow,
        Stream[] calldata _streams,
        uint16[] memory _coordinates
    ) internal returns (int256[] memory) {
        // initialize netted flow
        int256[] memory nettedFlow = new int256[](_flowVertices.length);

        // effect the stream transfers with acceptance calls
        for (uint16 i = 0; i < _streams.length; i++) {
            uint256[] memory ids = new uint256[](_streams[i].flowEdgeIds.length);
            uint256[] memory amounts = new uint256[](_streams[i].flowEdgeIds.length);
            uint256 streamTotal = uint256(0);
            for (uint16 j = 0; j < _streams[i].flowEdgeIds.length; j++) {
                // the Circles identifier coordinate is the first of three coordinates per flow edge
                ids[j] = toTokenId(_flowVertices[_coordinates[3 * _streams[i].flowEdgeIds[j]]]);
                amounts[j] = _flow[_streams[i].flowEdgeIds[j]].amount;
                streamTotal += amounts[j];
            }
            // use the first sink flow edge to recover the receiver coordinate
            uint16 receiverCoordinate = _coordinates[3 * _streams[i].flowEdgeIds[0] + 2];
            address receiver = _flowVertices[receiverCoordinate];
            _acceptanceCheck(
                _flowVertices[_streams[i].sourceCoordinate], // from
                receiver, // to
                ids, // batch of Circles identifiers terminating in receiver
                amounts, // batch of amounts terminating in receiver
                _streams[i].data // user-provided data for stream
            );
            // require(streamTotal <= uint256(type(int256).max));
            nettedFlow[_streams[i].sourceCoordinate] -= int256(streamTotal);
            // to recover the receiver coordinate, get the first sink
            nettedFlow[receiverCoordinate] += int256(streamTotal);
        }

        return nettedFlow;
    }

    function _matchNettedFlows(int256[] memory _streamsNettedFlow, int256[] memory _matrixNettedFlow) internal pure {
        if (_streamsNettedFlow.length != _matrixNettedFlow.length) {
            // Mismatch in netted flow length.
            revert CirclesArraysLengthMismatch(_streamsNettedFlow.length, _matrixNettedFlow.length, 5);
        }
        for (uint16 i = 0; i < _streamsNettedFlow.length; i++) {
            if (_streamsNettedFlow[i] != _matrixNettedFlow[i]) {
                // Intended flow does not match verified flow.
                revert CirclesHubNettedFlowMismatch(i, _streamsNettedFlow[i], _matrixNettedFlow[i]);
            }
        }
    }

    /**
     * Register human allows to register an avatar for a human,
     * and returns the status of the associated v1 Circles contract.
     * Additionally set the trust to self indefinitely.
     * @param _human address of the human to be registered
     */
    function _registerHuman(address _human) internal returns (address v1CirclesStatus) {
        // insert avatar into linked list; reverts if it already exists
        _insertAvatar(_human);

        // set the last mint time to the current timestamp for invited human
        // and register the v1 Circles contract status
        v1CirclesStatus = _avatarV1CirclesStatus(_human);
        MintTime storage mintTime = mintTimes[_human];
        mintTime.mintV1Status = v1CirclesStatus;
        mintTime.lastMintTime = uint96(block.timestamp);

        // trust self indefinitely, cannot be altered later
        _trust(_human, _human, INDEFINITE_FUTURE);

        return v1CirclesStatus;
    }

    /**
     * Register a group avatar.
     * @param _avatar address of the group registering
     * @param _mint address of the mint policy for the group
     * @param _treasury address of the treasury for the group
     * @param _name name of the group Circles
     * @param _symbol symbol of the group Circles
     */
    function _registerGroup(
        address _avatar,
        address _mint,
        address _treasury,
        string calldata _name,
        string calldata _symbol
    ) internal {
        // todo: we could check ERC165 support interface for mint policy
        if (_mint == address(0)) {
            // Mint address can not be zero.
            revert CirclesAddressCannotBeZero(2);
        }
        // todo: same check treasury is an ERC1155Receiver for receiving collateral
        if (_treasury == address(0)) {
            // Treasury address can not be zero.
            revert CirclesAddressCannotBeZero(3);
        }
        if (!nameRegistry.isValidName(_name)) {
            // Invalid group name.
            // name must be ASCII alphanumeric and some special characters
            revert CirclesInvalidString(_name, 0);
        }
        if (!nameRegistry.isValidSymbol(_symbol)) {
            // Invalid group symbol.
            // symbol must be ASCII alphanumeric and some special characters
            revert CirclesInvalidString(_symbol, 1);
        }

        // insert avatar into linked list; reverts if it already exists
        _insertAvatar(_avatar);

        // store the mint policy for the group
        mintPolicies[_avatar] = _mint;

        // store the treasury for the group
        treasuries[_avatar] = _treasury;
    }

    function _trust(address _truster, address _trustee, uint96 _expiry) internal {
        _upsertTrustMarker(_truster, _trustee, _expiry);

        emit Trust(_truster, _trustee, _expiry);
    }

    function _ensureAvatarsRegistered(address[] calldata _avatars) internal returns (uint256) {
        uint256 registrationCount = 0;
        for (uint256 i = 0; i < _avatars.length; i++) {
            if (avatars[_avatars[i]] == address(0)) {
                registrationCount++;
                _registerHuman(_avatars[i]);
            } else {
                if (!isHuman(_avatars[i])) {
                    // Only humans can be registered.
                    revert CirclesHubMustBeHuman(_avatars[i], 5);
                }
            }
        }

        return registrationCount;
    }

    /**
     * Check the status of an avatar's Circles in the Hub v1 contract,
     * and update the mint status of the avatar.
     * @param _human Address of the human avatar to check the v1 mint status of.
     */
    function _checkHumanV1CirclesStatus(address _human) internal {
        // check if v1 Circles is known to be stopped
        if (mintTimes[_human].mintV1Status != CIRCLES_STOPPED_V1) {
            // if v1 Circles is not known to be stopped, check the status
            address v1MintStatus = _avatarV1CirclesStatus(_human);
            _updateMintV1Status(_human, v1MintStatus);
        }
    }

    /**
     * Checks the status of an avatar's Circles in the Hub v1 contract,
     * and returns the address of the Circles if it exists and is not stopped.
     * Else, it returns the zero address if no Circles exist,
     * and it returns the address CIRCLES_STOPPED_V1 (0x1) if the Circles contract is stopped.
     * @param _avatar avatar address for which to check registration in Hub v1
     */
    function _avatarV1CirclesStatus(address _avatar) internal view returns (address) {
        address circlesV1 = hubV1.userToToken(_avatar);
        // no token exists in Hub v1, so return status is zero address
        if (circlesV1 == address(0)) return address(0);
        // return the status of the token
        if (ITokenV1(circlesV1).stopped()) {
            // return the stopped status of the Circles contract
            return CIRCLES_STOPPED_V1;
        } else {
            // return the address of the Circles contract if it exists and is not stopped
            return circlesV1;
        }
    }

    /**
     * Update the mint status of an avatar given the status of the v1 Circles contract.
     * @param _human Address of the human avatar to check the v1 mint status of.
     * @param _mintV1Status Mint status of the v1 Circles contract.
     */
    function _updateMintV1Status(address _human, address _mintV1Status) internal {
        MintTime storage mintTime = mintTimes[_human];
        // precautionary check to ensure that the last mint time is already set
        // as this marks whether an avatar is registered as human or not
        if (mintTime.lastMintTime == 0) {
            // Avatar must already be registered as human before we call update
            revert CirclesLogicAssertion(0);
        }
        // if the status has changed, update the last mint time
        // to avoid possible overlap of the mint between Hub v1 and Hub v2
        if (mintTime.mintV1Status != _mintV1Status) {
            mintTime.mintV1Status = _mintV1Status;
            mintTime.lastMintTime = uint96(block.timestamp);
        }
    }

    /**
     * Insert an avatar into the linked list of avatars.
     * Reverts on inserting duplicates.
     * @param _avatar avatar address to insert
     */
    function _insertAvatar(address _avatar) internal {
        if (avatars[_avatar] != address(0)) {
            // Avatar already inserted
            revert CirclesHubAvatarAlreadyRegistered(_avatar, 0);
        }
        avatars[_avatar] = avatars[SENTINEL];
        avatars[SENTINEL] = _avatar;
    }

    function _validateAddressFromId(uint256 _id, uint8 _code) internal pure returns (address) {
        address avatar = address(uint160(_id));
        if (uint256(uint160(avatar)) != _id) {
            // Invalid Circles identifier, not derived from address
            revert CirclesIdMustBeDerivedFromAddress(_id, _code);
        }
        return avatar;
    }

    /**
     * @dev abi.encodePacked of an array uint16[] would still pad each uint16 - I think;
     *      if abi packing does not add padding this function is redundant and should be thrown out
     *      Unpacks the packed coordinates from bytes.
     *      Each coordinate is 16 bits, and each triplet is thus 48 bits.
     * @param _packedData The packed data containing the coordinates.
     * @param _numberOfTriplets The number of coordinate triplets in the packed data.
     * @return unpackedCoordinates_ An array of unpacked coordinates (of length 3* numberOfTriplets)
     */
    function _unpackCoordinates(bytes calldata _packedData, uint256 _numberOfTriplets)
        internal
        pure
        returns (uint16[] memory unpackedCoordinates_)
    {
        if (_packedData.length != _numberOfTriplets * 6) {
            // Invalid packed data length
            revert CirclesArraysLengthMismatch(_packedData.length, _numberOfTriplets, 6);
        }

        unpackedCoordinates_ = new uint16[](_numberOfTriplets * 3);
        uint256 index = 0;

        // per three coordinates, shift each upper byte left
        for (uint256 i = 0; i < _packedData.length; i += 6) {
            unpackedCoordinates_[index++] = uint16(uint8(_packedData[i])) << 8 | uint16(uint8(_packedData[i + 1]));
            unpackedCoordinates_[index++] = uint16(uint8(_packedData[i + 2])) << 8 | uint16(uint8(_packedData[i + 3]));
            unpackedCoordinates_[index++] = uint16(uint8(_packedData[i + 4])) << 8 | uint16(uint8(_packedData[i + 5]));
        }
    }

    // Private functions

    /**
     * @dev Internal function to upsert a trust marker for a truster and a trusted address.
     * It will initialize the linked list for the truster if it does not exist yet.
     * If the trustee is not yet trusted by the truster, it will insert the trust marker.
     * It will update the expiry time for the trusted address.
     */
    function _upsertTrustMarker(address _truster, address _trusted, uint96 _expiry) private {
        if (_truster == address(0)) revert CirclesLogicAssertion(1);
        if (_trusted == address(0)) revert CirclesLogicAssertion(2);
        if (_trusted == SENTINEL) revert CirclesLogicAssertion(3);

        TrustMarker storage sentinelMarker = trustMarkers[_truster][SENTINEL];
        if (sentinelMarker.previous == address(0)) {
            // initialize the linked list for truster
            sentinelMarker.previous = SENTINEL;
        }

        TrustMarker storage trustMarker = trustMarkers[_truster][_trusted];
        if (trustMarker.previous == address(0)) {
            // insert the trust marker
            trustMarker.previous = sentinelMarker.previous;
            sentinelMarker.previous = _trusted;
        }

        // update the expiry; checks must be done by caller
        trustMarker.expiry = _expiry;
    }
}

// contract WrappedERC20 is ERC20, ERC1155Holder {
//     address public parentContract;
//     uint256 public parentTokenId;

//     constructor(string memory _name, string memory _symbol, address _parentContract, uint256 _parentTokenId)
//         ERC20(_name, _symbol)
//     {
//         parentContract = _parentContract;
//         parentTokenId = _parentTokenId;
//     }

//     //TODO - seems to not update total supply
//     function mint(address _to, uint256 _amount) public {
//         require(msg.sender == parentContract, "Only parent contract can mint");
//         _mint(_to, _amount);
//     }

//     function burn(address _from, uint256 _amount) public {
//         require(msg.sender == parentContract, "Only parent contract can burn");
//         _burn(_from, _amount);
//     }
// }
