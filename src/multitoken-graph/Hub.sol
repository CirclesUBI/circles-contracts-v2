// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;
import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";

contract Hub is ERC1155 {
    // Constants
    // TODO find hub deployment time
    uint256 public constant hubV1START = 1604136263;

    // People registering can mint up to one Circle per hour.
    // todo: should this be implemented without branching, ie. all be contracts
    address public constant PERSONAL_MINT = address(0x1);

    // Organizations can register with a no-mint policy.
    address public constant NO_MINT = address(0x2);

    address public constant SENTINEL = address(0x1);

    // State variables

    // Standard mint for Circle groups.
    address public immutable standardGroupMint;

    // linked list for registered avatars, used by all people,
    // groups and organizations.
    mapping(address => address) public avatars;

    mapping(address => uint256) public lastMintTimes;

    mapping(address => bool) public stopped;

    mapping(uint256 => WrappedERC20) public tokenIDToInfERC20;

    // Mint policy registered by avatar.
    mapping(address => address) public mintPolicies;

    mapping(address => address) public treasuries;

    // todo: ok for linked list, expiry 96 bits
    mapping(address => mapping(address => uint256)) public trustMarkers;

    // todo: do address
    mapping(uint256 => bytes32) public avatarIpfsUris;

    // Modifiers

    modifier isHuman(address _human) {
        require(lastMintTimes[_human] > 0, "");
        _;
    }

    modifier isGroup(address _group) {
        require(mintPolicies[_group] != address(0), "");
        _;
    }

    modifier isOrganization(address _organization) {
        require(
            avatars[_organization] != address(0) && mintPolicies[_organization] == address(0)
                && lastMintTimes[_organization] == uint256(0),
            ""
        );
        _;
    }

    // Constructor

    constructor(address _standardGroupMint) ERC1155("https://fallback.aboutcircles.com/v1/profile/{id}.json") {
        standardGroupMint = _standardGroupMint;
    }

    // External functions

    function registerHuman() external {
        //require(trusts(_inviter, msg.sender), "");
        // todo: v1 stopped & enable migration
        //require(...);
        insertAvatar(msg.sender);
        // mintPolicies[msg.sender] = PERSONAL_MINT;
        lastMintTimes[msg.sender] = block.timestamp;
        // treasuries[msg.sender] = address(0);

        // todo: let's welcome mint re-introduced; 3 days not demurraged
    }

    function insertAvatar(address avatar) internal {
        avatars[SENTINEL] = avatar;
        avatars[avatar] = SENTINEL;
    }

    function registerGroup(address _treasury, string calldata _name, string calldata _symbol) external {
        _registerGroup(msg.sender, standardGroupMint, _treasury, _name, _symbol);
    }

    function registerCustomGroup(address _mint, address _treasury, string calldata _name, string calldata _symbol)
        external
    {
        // msg.sender controls membership
        // minting: policy only
        // redemption: treasury contract (ideally generated from a factory - outside protocol)
        require(avatars[msg.sender] == address(0));
        _registerGroup(msg.sender, _mint, _treasury, _name, _symbol);
    }

    function registerOrganization(string calldata _name) external {
        insertAvatar(msg.sender);
        lastMintTimes[msg.sender] = 0;
    }

    function trust(address _trustReceiver, uint256 _expiry) external {
        // todo: make iterable; don't require expiry > block.timestamp
        // possibly: if _expiry < block.timestamp, set expiry = block.timestamp;
        trustMarkers[msg.sender][_trustReceiver] = _expiry;
    }

    // todo: happy with this name?
    function personalMint() external isHuman(msg.sender) {
        // do daily demurrage over claimable period; max 2week
        uint256 secondsElapsed = (block.timestamp - lastMintTimes[msg.sender]);
        require(secondsElapsed > 0, "No tokens available to mint yet");

        _mint(msg.sender, uint256(uint160(address(msg.sender))), secondsElapsed * 277777777777777, "");
        lastMintTimes[msg.sender] = block.timestamp; // Reset the registration time after minting
    }

    // graph transfers SHOULD allow personal -> group conversion en route

    // msg.sender holds collateral, and MUST be accepted by group
    // maybe less
    function groupMint(address _group, uint256[] calldata _collateral, uint256[] calldata _amounts) external {
        // check group and collateral exist
        // de-demurrage amounts
        // loop over collateral

        //require(
        //mintPolicies[_group].beforeMintPolicy(msg.sender, _group, _collateral, _amounts), "");

        safeBatchTransferFrom(msg.sender, treasuries[_group], _collateral, _amounts, ""); // treasury.on1155Received should only implement but nothing protocol related

        uint256 sumAmounts;
        // TODO sum up amounts
        sumAmounts = _amounts[0];
        _mint(msg.sender, uint256(uint160(_group)), sumAmounts, "");
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

    // do some unique name hash finding for personal circles
    // register with a salt for avoiding malicious blockage

    function uri(uint256 _id) public view override returns (string memory uri_) {
        if (avatarIpfsUris[_id] != bytes32(0)) {
            //return uri_ = string(abi.encodedPacked("ipfs://f0", bytes32ToHex(avatarIpfsUris[_id])));
        } else {
            return super.uri(_id);
        }
    }

    function setUri(bytes32 _ipfsCid) external {
        // msg.sender -> tokenId
        avatarIpfsUris[uint256(uint160(msg.sender))] = _ipfsCid;
    }

    // Internal functions

    function toDemurrageAmount(uint256 _amount, uint256 _timestamp) external {
        // timestamp should be "stepfunction" the timestamp
        // todo: ask where the best time step is

        if (_timestamp < hubV1START) _timestamp = block.timestamp;

        // uint256 durationSinceStart = _time - hubV1start;
        // do conversion
    }

    function ToInflationAmount(uint256 _amount, uint256 _timestamp) external {}

    function _registerGroup(
        address _avatar,
        address _mint,
        address _treasury,
        string calldata _name,
        string calldata _symbol
    ) internal {
        // do
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
