// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Graph is ERC1155 {
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

    // Mint policy registered by avatar.
    mapping(address => address) public mintPolicies;

    mapping(address => address) public treasuries;

    // todo: ok for linked list, expiry 96 bits
    mapping(address => mapping(address => uint256)) public trustMarkers;

    // todo: do address
    mapping(uint256 => bytes32) public avatarIpfsUris;

    // Modifiers

    modifier isHuman(address _human) {
        require(
            lastMintTimes[_human] > 0,
            ""
        );
        _;
    }

    modifier isGroup(address _group) {
        require(
            mintPolicies[_group] != address(0),
            ""
        );
        _;
    }

    modifier isOrganization(address _organization) {
        require(
            avatars[_organization] != address(0) &&
            mintPolicies[_organization] == address(0) &&
            lastMintTimes[_organization] == uint256(0),
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

    function registerGroup (address _treasury, string calldata _name, string calldata _symbol) external{
        _registerGroup(msg.sender, standardGroupMint, _treasury, _name, _symbol);
    }

    function registerCustomGroup (address _mint, address _treasury, string calldata _name, string calldata _symbol) external{
        // msg.sender controls membership
        // minting: policy only
        // redemption: treasury contract (ideally generated from a factory - outside protocol)
        require(avatars[msg.sender] == address(0));
        _registerGroup(msg.sender, _mint, _treasury, _name, _symbol);
    }

    function registerOrganization (string calldata _name) external{
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
  
    }

    // graph transfers SHOULD allow personal -> group conversion en route

    // msg.sender holds collateral, and MUST be accepted by group
    // maybe less 
    function groupMint(address _group, uint256[] calldata _collateral, uint256[] calldata _amounts) external{
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

    function singleSourcePathTransfer() external{
        //require(msg.sender == _source);
        // todo: sender does not have to be registered; can be anyone
        // can have multiple receivers
        // can allow zero-nett amounts, ie. closed paths are ok

        // consider adding a group mint targets array

        // emit Transfer intent events
    }

    function operatorPathTransfer() external{
        // msg.sender = oeprator 
        //require("nett sources have approved operator");
    }

    function wrapInflationaryERC20() external {
        // pass on name() but not modified
    }

    function unwrapInflationaryERC20() external {

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

        if (_timestamp<hubV1START) {_timestamp = block.timestamp;}

        // uint256 durationSinceStart = _time - hubV1start;
        // do conversion
    }
    
    function ToInflationAmount(uint256 _amount, uint256 _timestamp) external {

    }

    function _registerGroup(address _avatar, address _mint, address _treasury, string calldata _name, string calldata _symbol) internal {
        // do 
    }
}
