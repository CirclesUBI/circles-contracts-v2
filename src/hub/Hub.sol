// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "../migration/IHub.sol";
import "../migration/IToken.sol";
import "../circles/Circles.sol";
import "../groups/IMintPolicy.sol";
import "./IHub.sol";
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
contract Hub is Circles, IHubV2 {
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

    // Constants

    /**
     * @dev Welcome bonus for new avatars invited to Circles. Set to three days of non-demurraged Circles.
     */
    uint256 public constant WELCOME_BONUS = 3 * 24 * 10 ** 18;

    /**
     * @dev The minimum donation amount for registering a human as an organization,
     * paid in xDai, set to 0.1 xDai. The donation benefiary is arbitrary, and purely
     * reputational for the organization inviting people to Circles.
     */
    uint256 public constant MINIMUM_DONATION = 10 ** 17;

    /**
     * @dev The address used as the first element of the linked list of avatars.
     */
    address public constant SENTINEL = address(0x1);

    // State variables

    /**
     * @notice The Hub v1 contract address.
     */
    IHubV1 public immutable hubV1;

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
    address public immutable standardTreasury;

    /**
     * @notice The mapping of registered avatar addresses to the next avatar address,
     * stored as a linked list.
     * @dev This is used to store the linked list of registered avatars.
     */
    mapping(address => address) public avatars;

    // Mint policy registered by avatar.
    mapping(address => address) public mintPolicies;

    mapping(address => address) public treasuries;

    mapping(address => string) public names;

    mapping(address => string) public symbols;

    mapping(uint256 => WrappedERC20) public tokenIDToInfERC20;

    /**
     * @notice The iterable mapping of directional trust relations between avatars and
     * their expiry times.
     */
    mapping(address => mapping(address => TrustMarker)) public trustMarkers;

    /**
     * @notice tokenIDToCidV0Digest is a mapping of token IDs to the IPFS CIDv0 digest.
     */
    mapping(uint256 => bytes32) public tokenIdToCidV0Digest;

    // Events

    event RegisterHuman(address indexed avatar);
    event InviteHuman(address indexed inviter, address indexed invited);
    event RegisterOrganization(address indexed organization, string name);
    event RegisterGroup(
        address indexed group, address indexed mint, address indexed treasury, string name, string symbol
    );

    event Trust(address indexed truster, address indexed trustee, uint256 expiryTime);

    event CidV0(address indexed avatar, bytes32 cidV0Digest);

    // Modifiers

    /**
     * Modifier to check if the current time is during the bootstrap period.
     */
    modifier duringBootstrap() {
        require(block.timestamp < invitationOnlyTime, "Bootstrap period has ended.");
        _;
    }

    // Constructor

    /**
     * @notice Constructor for the Hub contract.
     * @param _hubV1 address of the Hub v1 contract
     * @param _inflation_day_zero timestamp of the start of the global inflation curve.
     * For deployment on Gnosis Chain this parameter should be set to midnight 15 October 2020,
     * or in unix time 1602786330 (deployment at 6:25:30 pm UTC) - 66330 (offset to midnight) = 1602720000.
     * @param _standardTreasury address of the standard treasury contract
     * @param _bootstrapTime duration of the bootstrap period (for v1 registration) in seconds
     * @param _fallbackUri fallback URI string for the ERC1155 metadata,
     * (todo: eg. "https://fallback.aboutcircles.com/v1/circles/{id}.json")
     */
    constructor(
        IHubV1 _hubV1,
        uint256 _inflation_day_zero,
        address _standardTreasury,
        uint256 _bootstrapTime,
        string memory _fallbackUri
    ) Circles(_inflation_day_zero, _fallbackUri) {
        require(address(_hubV1) != address(0), "Hub v1 address can not be zero.");
        require(_standardTreasury != address(0), "Standard treasury address can not be zero.");

        // initialize linked list for avatars
        avatars[SENTINEL] = SENTINEL;

        // store the Hub v1 contract address
        hubV1 = _hubV1;

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
    function registerHuman(bytes32 _cidV0Digest) external duringBootstrap {
        // only available for v1 users with stopped v1 mint, for initial bootstrap period
        address v1CirclesStatus = _registerHuman(msg.sender);
        require(v1CirclesStatus == CIRCLES_STOPPED_V1, "Avatar must have stopped v1 Circles contract.");

        // store the IPFS CIDv0 digest for the avatar metadata
        tokenIdToCidV0Digest[toTokenId(msg.sender)] = _cidV0Digest;

        emit RegisterHuman(msg.sender);

        emit CidV0(msg.sender, _cidV0Digest);
    }

    /**
     * @notice Invite human allows to register another human avatar.
     * The inviter must burn twice the welcome bonus of their own Circles,
     * and the invited human receives the welcome bonus in their personal Circles.
     * The inviter is set to trust the invited avatar.
     * @param _human avatar of the human to invite
     */
    function inviteHuman(address _human) external {
        require(isHuman(msg.sender), "Only humans can invite.");

        // register the invited human; reverts if they already exist
        _registerHuman(_human);

        // inviter must burn twice the welcome bonus of their own Circles
        _burn(msg.sender, toTokenId(msg.sender), 2 * WELCOME_BONUS);

        // invited receives the welcome bonus in their personal Circles
        _mint(_human, toTokenId(_human), WELCOME_BONUS, "");

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

        // store the IPFS CIDv0 digest for the group metadata
        tokenIdToCidV0Digest[toTokenId(msg.sender)] = _cidV0Digest;

        emit RegisterGroup(msg.sender, _mint, standardTreasury, _name, _symbol);

        emit CidV0(msg.sender, _cidV0Digest);
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

        // store the IPFS CIDv0 digest for the group metadata
        tokenIdToCidV0Digest[toTokenId(msg.sender)] = _cidV0Digest;

        emit RegisterGroup(msg.sender, _mint, _treasury, _name, _symbol);

        emit CidV0(msg.sender, _cidV0Digest);
    }

    /**
     * @notice Register organization allows to register an organization avatar.
     * @param _name name of the organization
     * @param _cidV0Digest IPFS CIDv0 digest for the organization metadata
     */
    function registerOrganization(string calldata _name, bytes32 _cidV0Digest) external {
        require(isValidName(_name), "Invalid organization name.");
        _insertAvatar(msg.sender);

        // store the name for the organization
        names[msg.sender] = _name;

        // store the IPFS CIDv0 digest for the organization metadata
        tokenIdToCidV0Digest[toTokenId(msg.sender)] = _cidV0Digest;

        emit RegisterOrganization(msg.sender, _name);

        emit CidV0(msg.sender, _cidV0Digest);
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
        require(avatars[msg.sender] != address(0), "Caller must be registered as an avatar in the Hub contract.");
        require(
            _trustReceiver != address(0) || _trustReceiver != SENTINEL, "You cannot trust the zero, or 0x1 address."
        );
        require(_trustReceiver != msg.sender, "You cannot edit your own trust relation.");
        // expiring trust cannot be set in the past
        if (_expiry < block.timestamp) _expiry = uint96(block.timestamp);
        _trust(msg.sender, _trustReceiver, _expiry);
    }

    /**
     * @notice Personal mint allows to mint personal Circles for a registered human avatar.
     */
    function personalMint() external {
        require(isHuman(msg.sender), "Only avatars registered as human can call personal mint.");
        // check if v1 Circles is known to be stopped
        if (mintTimes[msg.sender].mintV1Status != CIRCLES_STOPPED_V1) {
            // if v1 Circles is not known to be stopped, check the status
            address v1MintStatus = _avatarV1CirclesStatus(msg.sender);
            _updateMintV1Status(msg.sender, v1MintStatus);
        }

        // claim issuance if any is available
        _claimIssuance(msg.sender);
    }

    // graph transfers SHOULD allow personal -> group conversion en route

    /**
     * @notice Group mint allows to mint group Circles by providing the required collateral.
     * @param _group address of the group avatar to mint Circles of
     * @param _collateral array of (personal or group) avatar addresses to be used as collateral
     * @param _amounts array of amounts of collateral to be used for minting
     * @param _data (optional) additional data to be passed to the mint policy, treasury and minter
     */
    function groupMint(
        address _group,
        address[] calldata _collateral,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external {
        require(_collateral.length == _amounts.length, "Collateral and amount arrays must have equal length");
        require(_collateral.length > 0, "At least one collateral must be provided");
        require(isGroup(_group), "Group is not registered as an avatar.");

        // note: we don't need to check whether collateral circle ids are registered,
        // because only for registered collateral do non-zero balances exist to transfer,
        // so it suffices to check that all amounts are non-zero during summing.
        uint256 sumAmounts = 0;
        uint256[] memory collateralCirclesIds = new uint256[](_collateral.length);
        for (uint256 i = 0; i < _amounts.length; i++) {
            require(isTrusted(_group, _collateral[i]), "Collateral must be trusted");
            require(_amounts[i] > 0, "Non-zero collateral must be provided.");
            sumAmounts += _amounts[i];
            collateralCirclesIds[i] = toTokenId(_collateral[i]);
        }

        // Rely on the mint policy to determine whether the collateral is valid for minting
        require(
            IMintPolicy(mintPolicies[_group]).beforeMintPolicy(msg.sender, _group, _collateral, _amounts, _data),
            "Mint policy rejected mint."
        );

        // abi encode the group address into the data to send onwards to the treasury
        bytes memory metadataGroup = abi.encode(MetadataDefinitions.GroupMintMetadata({group: _group}));
        bytes memory dataWithGroup = abi.encode(
            MetadataDefinitions.Metadata({
                metadataType: MetadataDefinitions.MetadataType.GroupMint,
                metadata: metadataGroup,
                erc1155UserData: _data
            })
        );

        // note: treasury.on1155Received must implement and unpack the GroupMintMetadata to know the group
        safeBatchTransferFrom(msg.sender, treasuries[_group], collateralCirclesIds, _amounts, dataWithGroup);

        // mint group Circles to the sender and send the original _data onwards
        _mint(msg.sender, toTokenId(_group), sumAmounts, _data);
    }

    function stop() external {
        require(isHuman(msg.sender), "Only human can call stop.");
        MintTime storage mintTime = mintTimes[msg.sender];
        // stop future mints of personal Circles
        // by setting the last mint time to indefinite future.
        mintTime.lastMintTime = INDEFINITE_FUTURE;
    }

    function stopped(address _human) external view returns (bool) {
        require(isHuman(_human), "Only personal Circles can stopped or not stopped.");
        MintTime storage mintTime = mintTimes[msg.sender];
        return (mintTime.lastMintTime == INDEFINITE_FUTURE);
    }

    // check if path transfer can be fully ERC1155 compatible
    // note: matrix math needs to consider mints, otherwise it won't add up

    function singleSourcePathTransfer() external {
        //require(msg.sender == _source);
        // todo: sender does not have to be registered; can be anyone
        // can have multiple receivers
        // can allow zero-nett amounts, ie. closed paths are ok

        // consider adding a group mint targets array

        // emit Transfer intent events
    }

    function operatorPathTransfer() external {
        // msg.sender = oeprator
        //require("nett sources have approved operator");
    }

    // Public functions

    function getDeterministicAddress(uint256 _tokenId, bytes32 _bytecodeHash) public view returns (address) {
        return Create2.computeAddress(keccak256(abi.encodePacked(_tokenId)), _bytecodeHash);
    }

    function createERC20InflationWrapper(uint256 _tokenId, string memory _name, string memory _symbol) public {
        require(address(tokenIDToInfERC20[_tokenId]) == address(0), "Wrapper already exists");

        bytes memory bytecode =
            abi.encodePacked(type(WrappedERC20).creationCode, abi.encode(_name, _symbol, address(this), _tokenId));

        //bytes32 bytecodeHash = keccak256(bytecode);
        address wrappedToken = Create2.deploy(0, keccak256(abi.encodePacked(_tokenId)), bytecode);

        tokenIDToInfERC20[_tokenId] = WrappedERC20(wrappedToken);
    }

    function wrapInflationaryERC20(uint256 _tokenId, uint256 _amount) public {
        require(address(tokenIDToInfERC20[_tokenId]) != address(0), "Wrapper does not exist");
        safeTransferFrom(msg.sender, address(tokenIDToInfERC20[_tokenId]), _tokenId, _amount, "");
        tokenIDToInfERC20[_tokenId].mint(msg.sender, _amount);
    }

    function unwrapInflationaryERC20(uint256 _tokenId, uint256 _amount) public {
        require(address(tokenIDToInfERC20[_tokenId]) != address(0), "Wrapper does not exist");
        tokenIDToInfERC20[_tokenId].burn(msg.sender, _amount);
        safeTransferFrom(address(tokenIDToInfERC20[_tokenId]), msg.sender, _tokenId, _amount, "");
    }

    function wrapDemurrageERC20() external {
        // call on Hub for demurrage calculation in ERC20 contract

        // dont do a global allowance; but do do an ERC20Permit

        // do do a auto-factory of deterministic contract address
        // and how?
    }

    /**
     * set IPFS CIDv0 digest for the avatar metadata.
     * @param _ipfsCid IPFS CIDv0 digest for the avatar metadata
     */
    function setIpfsCidV0(bytes32 _ipfsCid) external {
        require(avatars[msg.sender] != address(0), "Avatar must be registered.");
        // todo: we should charge in CRC, but better done later through a storage market
        tokenIdToCidV0Digest[toTokenId(msg.sender)] = _ipfsCid;

        emit CidV0(msg.sender, _ipfsCid);
    }

    function toDemurrageAmount(uint256 _amount, uint256 _timestamp) external {
        // timestamp should be "stepfunction" the timestamp
        // todo: ask where the best time step is

        if (_timestamp < inflation_day_zero) _timestamp = block.timestamp;

        // uint256 durationSinceStart = _time - hubV1start;
        // do conversion
    }

    function ToInflationAmount(uint256 _amount, uint256 _timestamp) external {}

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
        return uint256(trustMarkers[_truster][_trustee].expiry) > block.timestamp;
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
    function isValidName(string memory _name) public pure returns (bool) {
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
    function isValidSymbol(string memory _symbol) public pure returns (bool) {
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

    // Internal functions

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
        require(_mint != address(0), "Mint address can not be zero.");
        // todo: same check treasury is an ERC1155Receiver for receiving collateral
        require(_treasury != address(0), "Treasury address can not be zero.");
        // name must be ASCII alphanumeric and some special characters
        require(isValidName(_name), "Invalid group name.");
        // symbol must be ASCII alphanumeric and some special characters
        require(isValidSymbol(_symbol), "Invalid group symbol.");

        // insert avatar into linked list; reverts if it already exists
        _insertAvatar(_avatar);

        // store the mint policy for the group
        mintPolicies[_avatar] = _mint;

        // store the treasury for the group
        treasuries[_avatar] = _treasury;

        // store the name and symbol for the group
        names[_avatar] = _name;
        symbols[_avatar] = _symbol;
    }

    function _trust(address _truster, address _trustee, uint96 _expiry) internal {
        _upsertTrustMarker(_truster, _trustee, _expiry);

        emit Trust(_truster, _trustee, _expiry);
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
        assert(mintTime.lastMintTime > 0);
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
        require(avatars[_avatar] == address(0), "Avatar already inserted");
        avatars[_avatar] = avatars[SENTINEL];
        avatars[SENTINEL] = _avatar;
    }

    // Private functions

    /**
     * @dev Internal function to upsert a trust marker for a truster and a trusted address.
     * It will initialize the linked list for the truster if it does not exist yet.
     * If the trustee is not yet trusted by the truster, it will insert the trust marker.
     * It will update the expiry time for the trusted address.
     */
    function _upsertTrustMarker(address _truster, address _trusted, uint96 _expiry) private {
        assert(_truster != address(0));
        assert(_trusted != address(0));
        assert(_trusted != SENTINEL);

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

contract WrappedERC20 is ERC20, ERC1155Holder {
    address public parentContract;
    uint256 public parentTokenId;

    constructor(string memory _name, string memory _symbol, address _parentContract, uint256 _parentTokenId)
        ERC20(_name, _symbol)
    {
        parentContract = _parentContract;
        parentTokenId = _parentTokenId;
    }

    //TODO - seems to not update total supply
    function mint(address _to, uint256 _amount) public {
        require(msg.sender == parentContract, "Only parent contract can mint");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        require(msg.sender == parentContract, "Only parent contract can burn");
        _burn(_from, _amount);
    }
}
