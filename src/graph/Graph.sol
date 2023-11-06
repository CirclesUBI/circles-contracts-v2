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

    /** Indefinitely, or approximate future infinity with uint256.max */
    uint256 public constant INDEFINITELY = type(uint256).max;

    /**
     * Upon removing trust edges from the graph, it is important
     * other processes (in particular the path finder processes)
     * know in advance the updated state of the graph (as otherwise
     * solutions might be invalid upon execution).
     * We can solve this by adding edges instantaneously - they don't cause
     * concurrency problems - but the removal of edges is enacted with a 
     * calculable delay: enacted after current interval + 1 interval.
     */
    uint256 public constant TRUST_INTERVAL = 1 minutes;

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
    mapping(ICircleNode => ICircleNode) public circleNodesIterable;

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

    event RegisterAvatar(address indexed avatar, address circleNode);
    event RegisterOrganization(address indexed organization);
    event RegisterGroup(address indexed group);

    event Trust(address indexed truster, address indexed trustee, uint256 expiryTime);

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

    modifier canBeTrusted(address _entity) {
        require(
            address(avatarToNode[_entity]) != address(0) ||
            // address(organizations[_entity]) != address(0) ||
            address(groups[IGroup(_entity)]) != address(0),            
            "Entity to be trusted must be a registered group or avatar."
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
        
        avatarToNode[msg.sender] = circleNode;
        _insertCircleNode(circleNode);

        _trust(msg.sender, msg.sender, INDEFINITELY);
    
        emit RegisterAvatar(msg.sender, address(circleNode));
    }

    function trust(address _entity) 
        onTrustGraph(msg.sender)
        canBeTrusted(_entity) 
        external
    {
        // by default trust indefinitely
        _trust(msg.sender, _entity, INDEFINITELY);
    }

    function trustWithExpiry(address _entity, uint256 _expiry)
        onTrustGraph(msg.sender)
        canBeTrusted(_entity)
        external
    {
        _trust(msg.sender, _entity, _expiry);
    }

    function untrust(address _avatar) external {

    }

    function nodeToAvatar(ICircleNode _node) external returns (address avatar_) {
        require(
            address(circleNodesIterable[_node]) != address(0),
            "Node is not registered on this graph."
        );
        return _node.avatar();
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

    function _trust(
        address _truster,
        address _trusted,
        uint256 _expiryTrustMarker
    ) internal {
        // take the floor of current timestamp to get current interval
        uint256 currentTrustInterval = block.timestamp / TRUST_INTERVAL;
        require(
            _expiryTrustMarker >= (currentTrustInterval + 1) * TRUST_INTERVAL,
            "Future expiry must be at least a full trust interval into the future."
        );
        // trust can instantly be registered
        trustMarkers[_truster][_trusted] = _expiryTrustMarker;

        emit Trust(_truster, _trusted, _expiryTrustMarker);
    }

    // Private functions

    function _insertCircleNode(ICircleNode _circleNode) private {
        assert(address(_circleNode) != address(0));
        assert(address(circleNodesIterable[_circleNode]) == address(0));
        // prepend the new CircleNode in the iterable linked list
        circleNodesIterable[_circleNode] = SENTINEL_CIRCLE;
        circleNodesIterable[SENTINEL_CIRCLE] = _circleNode;
    }

    // function registerTrust(IGraphNode _center)

}