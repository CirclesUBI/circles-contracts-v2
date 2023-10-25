// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./IGraph.sol";
import "./ICircleNode.sol";
import "./IGroup.sol";

/// @author CirclesUBI
/// @title A trust graph for path fungible tokens
contract Graph { // is IGraph {

    // Types

    /** 
     * Avatar is pointer to the SAFE contract that stands in
     * as a representation of the person on-chain. We want
     * to remain agnostic to any interface so it is a simple
     * type alias of Address.
     */
    type Avatar is address;

    /**
     * Organization is a type alias to refer to organizations
     * who can join the trust network, but do not get a corresponding
     * issuance node in the graph.
     */
    type Organization is address;

    // Constants

    /** Sentinel to mark the end of the linked list of Circle nodes */
    ICircleNode public constant SENTINEL_CIRCLE = ICircleNode(address(0x1));

    // State variables

    /** 
     * Avatar to node stores a mapping of which node has been created
     * for a given avatar.
     */
    mapping(Avatar => ICircleNode) public avatarToNode;

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
    mapping(Organization => Organization) public organizations;

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

    // Modifiers

    modifier onTrustGraph(address _entity) {
        require(
            address(organizations[_entity]) != address(0) ||
            address(groups[_entity]) != address(0) ||
            address(avatarToNode[_entity]) != address(0),
            "Entity is neither a registered organisation, group or avatar."
        );
        _;
    }

    // Constructor

    constructor(

    ) {

    }

    // External functions

    function trust(Avatar _avatar) external {

    }

    // Private functions

    // function registerTrust(IGraphNode _center)

}