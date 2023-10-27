// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

// import "./IGraph.sol";
import "./ICircleNode.sol";
import "./IGroup.sol";
import "../migration/IHub.sol";
import "../migration/IToken.sol";
import "../proxy/ProxyFactory.sol";

/// @author CirclesUBI
/// @title A trust graph for path fungible tokens
contract Graph is ProxyFactory {

    // Types

    /** 
     * Avatar is pointer to the SAFE contract that stands in
     * as a representation of the person on-chain. We want
     * to remain agnostic to any interface so it is a simple
     * type alias of Address.
     */
    // note: Explicit type conversion not allowed from "Graph.Avatar" to "address".solidity(9640)
    // todo: figure out whether this is a solidity compiler bug, why would this be prohibited?
    // type Avatar is address;

    /**
     * Organization is a type alias to refer to organizations
     * who can join the trust network, but do not get a corresponding
     * issuance node in the graph.
     */
    // todo: same problem with types and casting
    // type Organization is address;

    // Constants

    /** Sentinel to mark the end of the linked list of Circle nodes */
    ICircleNode public constant SENTINEL_CIRCLE = ICircleNode(address(0x1));

    // State variables

    /** Hub v1 contract reference to ensure correct migration of avatars */
    IHubV1 public immutable ancestor;

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
        IHubV1 _ancestor
    ) {
        ancestor = _ancestor;
    }

    // External functions

    function registerAvatar() 
        external 
        notYetOnTrustGraph(msg.sender)
    {
        (address ancestorToken, bool ancestorTokenStopped) = 
            checkHubV1Migration(msg.sender);
        // todo: setting up proxy deployment of CircleNode and explicit implementation
    }

    function trust(address _avatar) external {

    }

    // Internal functions

    function checkHubV1Migration(address _avatar) 
        internal
        returns (
            address ancestorToken_,
            bool ancestorMintingStopped_
        )
    {
        ancestorMintingStopped_ = false;
        ancestorToken_ = ancestor.userToToken(_avatar);
        if (ancestorToken_ != address(0)) {
            // avatar has been registered in the ancestor graph
            // check if the old token has been stopped
            ancestorMintingStopped_ = !ITokenV1(ancestorToken_).stopped();
        }
    }

    // Private functions

    // function registerTrust(IGraphNode _center)

}