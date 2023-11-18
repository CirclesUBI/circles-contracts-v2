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

    /**
     * Sentinel to mark the end of the linked list of Circle nodes
     */
    ICircleNode public constant SENTINEL_CIRCLE = ICircleNode(address(0x1));

    /**
     * Callprefix for ICircleNode::setup function
     */
    bytes4 public constant CIRCLENOODE_SETUP_CALLPREFIX = bytes4(keccak256("setup(address,bool,address[])"));

    /**
     * Indefinitely, or approximate future infinity with uint256.max
     */
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

    /**
     * Hub v1 contract reference to ensure correct migration of avatars
     */
    IHubV1 public immutable ancestor;

    /**
     * Master copy of the circle node contract to deploy proxy's for
     */
    ICircleNode public immutable masterCopyCircleNode;

    /**
     * Avatar to node stores a mapping of which node has been created
     * for a given avatar.
     */
    mapping(address => ICircleNode) public avatarToNode;

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

    event PauseClaim(address indexed claimer, address indexed node);

    // Modifiers

    modifier notYetOnTrustGraph(address _entity) {
        require(
            address(avatarToNode[_entity]) == address(0) && address(organizations[_entity]) == address(0)
                && address(groups[IGroup(_entity)]) == address(0),
            "Entity is already registered as an avatar, an organisation or as a group."
        );
        _;
    }

    modifier onTrustGraph(address _entity) {
        require(
            address(avatarToNode[_entity]) != address(0) || address(organizations[_entity]) != address(0)
                || address(groups[IGroup(_entity)]) != address(0),
            "Entity is neither a registered organisation, group or avatar."
        );
        _;
    }

    modifier canBeTrusted(address _entity) {
        require(
            address(avatarToNode[_entity]) != address(0)
            // address(organizations[_entity]) != address(0) ||
            || address(groups[IGroup(_entity)]) != address(0),
            "Entity to be trusted must be a registered group or avatar."
        );
        _;
    }

    modifier activeCircleNode(ICircleNode _node) {
        require(address(circleNodesIterable[_node]) != address(0), "Node is not registered to this graph.");
        require(_node.isActive(), "Circle node must be active.");
        _;
    }

    // Constructor

    constructor(IHubV1 _ancestor, ICircleNode _masterCopyCircleNode) {
        ancestor = _ancestor;
        masterCopyCircleNode = _masterCopyCircleNode;
    }

    // External functions

    function registerAvatar() external notYetOnTrustGraph(msg.sender) {
        // there might not (yet) be a token in the ancestor graph
        (bool objectToStartMint, address[] memory migrationTokens) = checkAncestorMigrations(msg.sender);

        bytes memory circleNodeSetupData =
            abi.encodeWithSelector(CIRCLENOODE_SETUP_CALLPREFIX, msg.sender, !objectToStartMint, migrationTokens);
        ICircleNode circleNode = ICircleNode(address(createProxy(address(masterCopyCircleNode), circleNodeSetupData)));

        avatarToNode[msg.sender] = circleNode;
        _insertCircleNode(circleNode);

        _trust(msg.sender, msg.sender, INDEFINITELY);

        emit RegisterAvatar(msg.sender, address(circleNode));
    }

    function trust(address _entity) external onTrustGraph(msg.sender) canBeTrusted(_entity) {
        require(_entity != msg.sender, "Cannot edit your own trust relation.");
        // by default trust indefinitely
        _trust(msg.sender, _entity, INDEFINITELY);
    }

    function trustWithExpiry(address _entity, uint256 _expiry)
        external
        onTrustGraph(msg.sender)
        canBeTrusted(_entity)
    {
        require(_entity != msg.sender, "Cannot edit your own trust relation.");
        _trust(msg.sender, _entity, _expiry);
    }

    function untrust(address _entity) external onTrustGraph(msg.sender) {
        require(_entity != msg.sender, "Cannot edit your own trust relation.");
        // wait at least a full trust interval before the edge can expire
        uint256 earliestExpiry = ((block.timestamp / TRUST_INTERVAL) + 1) * TRUST_INTERVAL;

        require(trustMarkers[msg.sender][_entity] > earliestExpiry, "Trust is already set to (have) expire(d).");
        trustMarkers[msg.sender][_entity] = earliestExpiry;

        emit Trust(msg.sender, _entity, earliestExpiry);
    }

    // Note: a user can signup in v2 first, when no associated token in v1 exists
    //       as such we would start minting in v2. We cover for the edge case
    //       where a user signs up in v1, after signing up in v2, and would mint
    //       double, by introducing 'pause()', in addition to 'stop()'.
    //       With pause, an avatar can have a token in multiple graphs, but we
    //       can ensure that all-but-one token can always be paused/unpaused.
    function claimNodeMustPause(ICircleNode _node) external activeCircleNode(_node) returns (bool paused_) {
        // pause is idempotent, but emitting the event, or possible slashing is not
        // but in the modifier we already check is `activeCircleNode`,
        // which additionally prevents false claims if v2 node would have been stopped.

        bool conflict = checkConcurrentMinting(_node);

        if (conflict) {
            _node.pause();
            // todo: the hub can enforce slashing of circles and reward for claimer here
            emit PauseClaim(msg.sender, address(_node));
            return paused_ = true;
        }
        return paused_ = false;
    }

    function claimToUnpauseNode() external returns (bool paused_) {
        ICircleNode node = avatarToNode[msg.sender];
        // only the avatar can call to unpause their node.
        require(address(node) != address(0), "Caller must be the registered avatar for a node on this graph.");
        require(!node.stopped(), "A stopped Cirlce node cannot be unpaused.");

        bool conflict = checkConcurrentMinting(node);
        if (!conflict) {
            node.unpause();
            return paused_ = false;
        }
        return paused_ = true;
    }

    // Public functions

    function singlePathTransfer(
        uint16 _senderCoordinateIndex,
        uint16 _receiverCoordinateIndex,
        uint256 _amount,
        address[] calldata _flowVertices,
        uint256[] calldata _flow,
        bytes calldata _packedCoordinates
    ) public {
        // first unpack the coordinates to array of uint16
        uint16[] memory coordinates = _unpackCoordinates(_packedCoordinates, _flow.length);
        
        require(
            _flowVertices[_senderCoordinateIndex] == msg.sender,
            "For a single path transfer the message must be sent by the sender."
        );

        // forcibly cast amount to int256
        int256 nettFlow = int256(_amount);
        // set up the intended netted flow
        int256[] memory intendedNettedFlow = new int256[](_flowVertices.length);
        // set the nett flow to go from sender to receiver
        intendedNettedFlow[_senderCoordinateIndex] = int256(-1) * nettFlow;
        intendedNettedFlow[_receiverCoordinateIndex] = nettFlow;

        int256[] memory verifiedNettedFlow = _verifyFlowMatrix(
            _flowVertices,
            _flow,
            coordinates,
            false
        );

        // match the equality of the intended flow with the verified path flow
        _matchNettedFlows(
            intendedNettedFlow,
            verifiedNettedFlow
        );
    }

    function isTrusted(address _truster, address _trustee)
        public
        view
        onTrustGraph(_truster)
        canBeTrusted(_trustee)
        returns (bool trusted_)
    {
        uint256 currentTrustInterval = block.timestamp / TRUST_INTERVAL;

        return trustMarkers[_truster][_trustee] >= currentTrustInterval;
    }

    function nodeToAvatar(ICircleNode _node) public view returns (address avatar_) {
        require(address(circleNodesIterable[_node]) != address(0), "Node is not registered on this graph.");
        return _node.avatar();
    }

    function checkConcurrentMinting(ICircleNode _node) public view returns (bool conflict_) {
        // get the associated avatar for the token
        address avatar = nodeToAvatar(_node);
        require(avatar != address(0), "Unknown Circle node, cannot check for conflicts.");
        require(_node.isActive(), "Search for conflict requires the node to be active.");

        // check recursively all paths to other graphs
        // (for now only v1 ancestor graph)
        ITokenV1 ancestorToken = ITokenV1(ancestor.userToToken(avatar));
        require(
            ancestorToken != ITokenV1(address(0)),
            "Ancestor token must exist for a conflict to exist with this Circle node."
        );
        // if an ancestor token exists, but is not stopped (v1 only has stopped)
        // then we do have a conflict.
        return conflict_ = !ancestorToken.stopped();
    }

    function checkAncestorMigrations(address _avatar)
        public
        view
        returns (bool objectToStartMint_, address[] memory migrationTokens_)
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

    function circleNodeForEntity(
        address _entity
    ) public view canBeTrusted(_entity) returns (
        ICircleNode circleNode_
    ) {
        // first see if the entity is a registered avatar
        circleNode_ = avatarToNode[_entity];
        if (address(circleNode_) != address(0)) {
            return circleNode_;
        }
        // we already check this in modifier, by exclusion. Leave this here during development.
        assert(address(groups[IGroup(_entity)]) != address(0));
        // return the group itself as the circle node
        assert(false); // todo: not yet implemented, think proper about group currencies
        return ICircleNode(_entity);
    }

    // Internal functions

    /**
     * @param _flowVertices Flow vertices list (without repetition) the addresses of entities
     *     involved in the (batch) of path transfers. The vertices are the columns of a flow marix.
     *     To make it gas-efficient to ensure no duplicate entries are in the array of _flowVertices
     *     the addresses must be sorted in ascending order.
     * @param _flow Flow is the amount of tokens that flow (for positive flow number),
     *     from "from" to "to" (and a negative flow 'flows' from "to" to "from").
     *     Note that we need to cast this to int256 to add and subtract numbers, so it will revert
     *     for any flow number bigger than type(int256).max.
     * @param _coordinates For each flow, three coordinates must be provided to characterize the flow.
     *     The coordinates are the array indices of the _flowVertices array provided, expressed as uint16.
     *     1. The first coordinate indicates the token to be sent, which will be looked up from the entity in
     *     the _flowVertices array under the coordinate index.
     *     2. The second coordindate indicates "from" whom the token should be sent. Again this is expressed
     *     as the coordinate index of the _flowVertices array. The sender should have a sufficient balance,
     *     but we rely on the default requirements of transfer to not underflow the balance upon executing
     *     the transfer.
     *     3. The third coordinate indicates "to" whom the token should be sent. Again the coordinate is
     *     used to look up under the index in the _flowVertices array the receiver entity address.
     *     This entity should currently trust, and as such accept the token provided in the first coordinate,
     *     otherwise _verifyFlowMatrix will revert.
     * @param _cleanupClosedPath When _cleanupClosedPath is `true`, the `to` coordinate MUST equal the `token`
     *     coordinate. This restricts all flows to return tokens to the original minter address.
     *     Let's explain the rationale a bit more verbose: a special path transfer is also the case
     *     where all flow vertices have a conserved balance after the path transfer,
     *     ie. there is no net sender or receiver.
     *     This is particularly useful if anyone wants to clean up balances,
     *     by swapping tokens back to their original minters. For a closed path no signatures or intents are
     *     required, because everyone simply exchanges tokens they trust. However, we want to prevent irrational
     *     actors from simply disturbing the network by shuffling tokens around without good reason.
     *     We therefore make a closed path more difficult by only allowing tokens to be sent back to the original
     *     minters, and not allow them to be shuffled among people who trust someone's token.
     * @return nettedFlow_ The nettedFlow_ is returned as an array of int256 (not uint256!) of the same length
     *     as the input _flowVertices array, and should be read as concerning the same entities as this input array.
     *     - A negative netted flow indicates a net amount sent from this entity (summed over all tokens).
     *     - Zero indicates that (respecting trust relations) an equal amount was received as was sent.
     *     This can be either because the entity was an intermediate vertex along the path, or because in a batch
     *     they incidentally initiated to send as much as they happened to have received in this batch.
     *     - Finally a positive netted flow indicates a net received amount of tokens.
     */
    function _verifyFlowMatrix(
        address[] calldata _flowVertices,
        uint256[] calldata _flow,
        uint16[] memory _coordinates,
        bool _cleanupClosedPath
    ) internal returns (int256[] memory nettedFlow_) {
        require(3 * _flow.length == _coordinates.length, "Every flow row must have three coordinates.");
        // todo: we should probably introduce a lower maximum,
        // because 65k vertices probably never fits in a block
        require(_flowVertices.length <= type(uint16).max, "Flow matrix cannot have more than 65536 columns");
        require(_flowVertices.length > 0 && _flow.length > 0, "Must be a flow matrix.");

        // initialize the netted flow array
        nettedFlow_ = new int256[](_flowVertices.length);

        // check for membership of all flow vertices
        for (uint256 i = 0; i < _flowVertices.length - 1; i++) {
            require(
                uint160(_flowVertices[i]) < uint160(_flowVertices[i + 1]),
                "Flow vertices must be sorted in ascending order and cannot repeat."
            );
            address entity = _flowVertices[i];
            require(
                address(avatarToNode[entity]) != address(0) || address(organizations[entity]) != address(0)
                    || address(groups[IGroup(entity)]) != address(0),
                "Flow vertex is neither a registered organisation, group or avatar."
            );
        }
        // don't miss checking the last vertex for registration on the graph
        address lastEntity = _flowVertices[_flowVertices.length - 1];
        require(
            address(avatarToNode[lastEntity]) != address(0) || address(organizations[lastEntity]) != address(0)
                || address(groups[IGroup(lastEntity)]) != address(0),
            "Flow vertex is neither a registered organisation, group or avatar."
        );

        // iterate over the coordinate index
        uint16 index = uint16(0);

        // iterate over all flow edges in the path
        for (uint256 i = 0; i < _flow.length; i++) {
            // retrieve the flow vertices associated with this flow edge
            address tokenEntity = _flowVertices[_coordinates[index++]];
            uint16 fromIndex = index++;
            address from = _flowVertices[_coordinates[fromIndex]];
            uint16 toIndex = index++;
            address to = _flowVertices[_coordinates[toIndex]];
            // cast the flow amount from uint256 to int256,
            // will revert if flow is larger than type(int256).max
            int256 flow = int256(_flow[i]);

            ICircleNode node = circleNodeForEntity(tokenEntity);

            // check receiver is within the trust circle of the token being sent
            require(isTrusted(to, tokenEntity), "The receiver does not trust the token being sent in the flow edge.");
            require(
                !_cleanupClosedPath || (to == tokenEntity),
                "For closed paths, tokens may only be sent to original avatar."
            );

            // execute the path transfer; rely on reverting if balance fails
            node.pathTransfer(from, to, _flow[i]);

            // nett the flow across tokens
            nettedFlow_[fromIndex] -= flow;
            nettedFlow_[toIndex] += flow;
        }

        return nettedFlow_;
    }

    function _matchNettedFlows(
        int256[] memory _intendedNettedFlow,
        int256[] memory _verifiedNettedFlow
    ) internal {
        assert(_intendedNettedFlow.length == _verifiedNettedFlow.length);
        for (uint256 i = 0; i < _intendedNettedFlow.length; i++) {
            require(
                _intendedNettedFlow[i] == _verifiedNettedFlow[i],
                "Intended flow does not match verified flow."
            );
        }
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
        require(_packedData.length == _numberOfTriplets * 6, "Invalid packed data length");

        unpackedCoordinates_ = new uint16[](_numberOfTriplets * 3);
        uint256 index = 0;

        // per three coordinates, shift each upper byte left
        for (uint256 i = 0; i < _packedData.length; i += 6) {
            unpackedCoordinates_[index++] = uint16(uint8(_packedData[i])) << 8 | uint16(uint8(_packedData[i + 1]));
            unpackedCoordinates_[index++] = uint16(uint8(_packedData[i + 2])) << 8 | uint16(uint8(_packedData[i + 3]));
            unpackedCoordinates_[index++] = uint16(uint8(_packedData[i + 4])) << 8 | uint16(uint8(_packedData[i + 5]));
        }
    }

    // function _verifyFlowMatrix(
    //     address[] memory pathAvatars,

    // ) internal view returns ()

    function _trust(address _truster, address _trusted, uint256 _expiryTrustMarker) internal {
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
        assert(_circleNode != SENTINEL_CIRCLE);
        assert(address(circleNodesIterable[_circleNode]) == address(0));
        // prepend the new CircleNode in the iterable linked list
        circleNodesIterable[_circleNode] = SENTINEL_CIRCLE;
        circleNodesIterable[SENTINEL_CIRCLE] = _circleNode;
    }
}
