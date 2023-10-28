// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

// import "./IGraph.sol";
import "./ICircleNode.sol";
import "./IGroup.sol";
import "./IGraph.sol";
import "../migration/IHub.sol";
import "../migration/IToken.sol";
import "../proxy/ProxyFactory.sol";

/// @author CirclesUBI
/// @title A trust graph for path fungible tokens
contract Graph is ProxyFactory, IGraph {

    // Constants

    /** Sentinel to mark the end of the linked list of Circle nodes */
    ICircleNode public constant SENTINEL_CIRCLE = ICircleNode(address(0x1));

    /** Callprefix for ICircleNode::setup function */
    bytes4 public constant CIRCLENOODE_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(address,bool,address[])"
        )
    );

    // State variables

    /** Hub v1 contract reference to ensure correct migration of avatars */
    IHubV1 public immutable ancestor;

    /** Master copy of the circle node contract to deploy proxy's for */
    ICircleNode public immutable masterCopyCircleNode;

    /** 
     * Avatar to node stores a mapping of which node has been created
     * for a given avatar.
     */
    mapping(address => ICircleNode) public avatarToNode;

    /**
     * Node to avatar stores an inverse mapping of the avatar given the node.
     * @dev this not actively used, and the node stores the owner, so consider
     *      replacing it with a linked list of all the nodes; or removing it
     */
    // mapping(ICircleNode => Avatar) public nodeToAvatar;

    /**
     * Circle nodes iterator allows to list all circle nodes from contract state
     * independent of indexer logic.
     */
    mapping(ICircleNode => ICircleNode) public circleNodesIterator;

    /**
     * Organizations can enter the trust graph
     * without creating a circle node themselves.
     */
    mapping(address => address) public organizations;

    /**
     * Groups, like organizations can enter the trust graph without creating
     * a circle node themselves. Groups can wrap tokens into a group currency.
     * Groups can be trusted to enable the flow of group currency.
     */
    mapping(IGroup => IGroup) public groups;

    /** 
     * Trust markers map the time marker at which trust of an entity
     * for a trusted entity expires. By default, for all entities
     * the trust marks expiration at the zero-th marker, effectively
     * not trusting.
     * Upon trusting we can immediately set the trust marker to MAX_UINT256,
     * however, upon untrusting (or edge removal), we need to synchronize
     * the state of the smart contract with other processes,
     * so we want to introduce a predictable time marker for the expiration of trust.
     */
    mapping(address => mapping(address => uint256)) public trustMarkers;

    // Events

    event Signup(address indexed avatar, address circleNode);
    event OrganizationSignup(address indexed organization);
    event GroupSignup(address indexed group);

    // Modifiers

    modifier notYetOnTrustGraph(address _entity) {
        require(
            address(avatarToNode[_entity]) == address(0) &&
            address(organizations[_entity]) == address(0) &&
            address(groups[IGroup(_entity)]) == address(0),
            "Entity is already registered as an avatar, an organisation or as a group."
        );
        _;
    }

    modifier onTrustGraph(address _entity) {
        require(
            address(avatarToNode[_entity]) != address(0) ||
            address(organizations[_entity]) != address(0) ||
            address(groups[IGroup(_entity)]) != address(0),            
            "Entity is neither a registered organisation, group or avatar."
        );
        _;
    }

    // Constructor

    constructor(
        IHubV1 _ancestor,
        ICircleNode _masterCopyCircleNode
    ) {
        ancestor = _ancestor;
        masterCopyCircleNode = _masterCopyCircleNode;
    }

    // External functions

    function registerAvatar() 
        external 
        notYetOnTrustGraph(msg.sender)
    {
        // there might not (yet) be a token in the ancestor graph
        (bool objectToStartMint, address[] memory migrationTokens) = 
            checkAncestorMigrations(msg.sender);

        bytes memory circleNodeSetupData = abi.encodeWithSelector(
            CIRCLENOODE_SETUP_CALLPREFIX,
            msg.sender,
            !objectToStartMint,
            migrationTokens
        );
        ICircleNode circleNode = ICircleNode(address(
            createProxy(address(masterCopyCircleNode), circleNodeSetupData)));
    
    }

    function trust(address _avatar) external {

    }

    function untrust(address _avatar) external {

    }

    // Public functions

    function checkAncestorMigrations(address _avatar) 
        public
        returns (
            bool objectToStartMint_,
            address[] memory migrationTokens_
        )
    {
        objectToStartMint_ = false;
        address ancestorToken = ancestor.userToToken(_avatar);
        if (ancestorToken != address(0)) {
            migrationTokens_ = new address[](1);
            // append ancestorToken to migrationTokens_
            migrationTokens_[0] = ancestorToken;
            // Avatar has been registered in the ancestor graph,
            // so check if the old token has been stopped.
            // If it has not been stopped, object to start the mint of v2.
            objectToStartMint_ = !ITokenV1(ancestorToken).stopped();
        } else {
            migrationTokens_ = new address[](0);
        }
    }

    // Internal functions

    // Private functions

    // function registerTrust(IGraphNode _center)

}