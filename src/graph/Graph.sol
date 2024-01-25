// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

// import "./IGraph.sol";
import "./ICircleNode.sol";
import "./IGraph.sol";
import "../mint/IMintSplitter.sol";
import "../migration/IHub.sol";
import "../migration/IToken.sol";
import "../proxy/ProxyFactory.sol";

/// @author CirclesUBI
/// @title A trust graph for path fungible tokens
contract Graph is ProxyFactory, IGraph {
    // Type declarations

    /**
     * @notice A trust marker stores the address of the previously
     *     trusted entity such that it can be iterated as a linked list;
     *     as well as the remaining 96 bits for an expiry timestamp
     *     after which the trust of this entity expires.
     */
    struct TrustMarker {
        address previous;
        uint96 expiry;
    }

    // Constants

    /**
     * Sentinel to mark the end of the linked list of Circle nodes or entities
     */
    address public constant SENTINEL = address(0x1);

    /**
     * Callprefix for IAvatarCircleNode::setup function
     */
    bytes4 public constant AVATAR_CIRCLE_SETUP_CALLPREFIX = bytes4(keccak256("setup(address)"));

    /**
     * Callprefix for IGroupCircleNode::setup function
     */
    bytes4 public constant GROUP_CIRCLE_SETUP_CALLPREFIX = bytes4(keccak256("setup(address,int128)"));

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
    uint256 public constant OPERATOR_INTERVAL = 1 minutes;

    // State variables

    /**
     * Mint splitter ensures that across composite graphs (including legacy Hub V1 graph)
     * the central invariant of one circle per human per hour is respected.
     * Upon issuing circles, the graph MUST always call upon the mint splitter to know what
     * the current allocation - if any - is for this graph, and what the earliest time is
     * from which an issuance can be calculcated.
     */
    IMintSplitter public immutable mintSplitter;

    /**
     * @notice Ancestor Circle Migrator contract can call on this graph to migrate
     *     Circles balance from an account on a Circle contract in Hub v1
     *     into the Circle contract of the same associated avatar.
     */
    address public immutable ancestorCircleMigrator;

    /**
     * Master copy of the avatar circle node contract to deploy proxy's for
     * when an avatar signs up.
     */
    IAvatarCircleNode public immutable masterCopyAvatarCircleNode;

    /**
     * Master copy of the group circle node contract to deploy proxy's for
     * when a group signs up.
     */
    IGroupCircleNode public immutable masterCopyGroupCircleNode;

    /**
     * Avatar to node stores a mapping of which node has been created
     * for a given avatar.
     */
    mapping(address => IAvatarCircleNode) public avatarToCircle;

    /**
     * Avatar Circle nodes iterator allows to list all avatar circle nodes
     * from contract state independent of indexer logic.
     */
    mapping(ICircleNode => ICircleNode) public avatarCircleNodesIterable;

    /**
     * @notice Group to node stores a mapping of which circle node
     *     has been created for a group.
     */
    mapping(address => IGroupCircleNode) public groupToCircle;

    /**
     * Groups can enter the trust graph and create a group circles contract.
     * Group circles wrap personal circles into a group currency.
     * Groups can be trusted to enable the flow of group currency
     * over the trust graph.
     * Group circle nodes iterable is a subset of all circle nodes iterable
     * specifically to select for all group circles on the graph.
     */
    mapping(ICircleNode => ICircleNode) public groupCircleNodesIterable;

    /**
     * Organizations can enter the trust graph
     * without creating a circle node themselves.
     */
    mapping(address => address) public organizations;

    /**
     * Trust markers map the time marker at which trust of an entity
     * for a trusted entity expires. By default, for all entities
     * the trust marks expiration at the zero-th marker, effectively
     * not trusting.
     * Upon trusting we can immediately set the trust marker to MAX_UINT256,
     * however, upon untrusting (or edge removal), we need to synchronize
     * the state of the smart contract with other processes,
     * so we want to introduce a predictable time marker for the expiration of trust.
     * Trust markers additionally store a linked list to iterate through the trusted
     * entities.
     */
    mapping(address => mapping(address => TrustMarker)) public trustMarkers;

    /**
     * Authorized graph operators stores a mapping from (address entity, address operator)
     * to uint256 expiry timestamp. As the default value is zero, all operator addresses
     * are disabled, but by setting the expiry time to a future timestamp, the operator
     * can be enabled for that entity.
     */
    mapping(address => mapping(address => uint256)) public authorizedGraphOperators;

    /**
     * Global allowances allow an entity to set a spender and a global allowance across
     * all their balances in this graph. If a non-zero allowance is set, it overrides
     * the local allowance of all the ERC20 allowances for that owner(entity).
     */
    mapping(address => mapping(address => uint256)) public globalAllowances;

    /**
     * Global allowance timestamps tracks the timestamp when the global allowance was set.
     * If the global allowance timestamp is more recent than a local (at an ERC20 CircleNode)
     * timestamp of when the local allowance was last set, then the global allowance overrides
     * the local allowance value.
     * When the timestamps of local and global allowance would be equal (eg. set in the same block)
     * then the local allowance overrides the global allowance value.
     */
    mapping(address => mapping(address => uint256)) public globalAllowanceTimestamps;

    // Events

    event RegisterAvatar(address indexed avatar, address circleNode);
    event RegisterOrganization(address indexed organization);
    event RegisterGroup(address indexed group, int128 exitFee);

    event Trust(address indexed truster, address indexed trustee, uint256 expiryTime);

    event AuthorizedGraphOperator(address indexed entity, address indexed operator, uint256 expiryTime);
    event RevokedGraphOperator(address indexed entity, address indexed operator, uint256 expiryTime);

    event GlobalApproval(address indexed entity, address indexed spender, uint256 amount);

    // Modifiers

    modifier onlyAncestorMigrator() {
        require(msg.sender == ancestorCircleMigrator, "Only ancestor circle migrator contract can call this function.");
        _;
    }

    modifier notOnTrustGraph(address _entity) {
        require(
            address(avatarToCircle[_entity]) == address(0) && address(organizations[_entity]) == address(0)
                && address(groupToCircle[_entity]) == address(0),
            "Address is already registered as an avatar, an organisation or as a group."
        );
        _;
    }

    modifier onTrustGraph(address _entity) {
        require(
            address(avatarToCircle[_entity]) != address(0) || address(organizations[_entity]) != address(0)
                || address(groupToCircle[_entity]) != address(0),
            "Entity is neither a registered organisation, group or avatar."
        );
        _;
    }

    modifier canBeTrusted(address _entity) {
        require(
            address(avatarToCircle[_entity]) != address(0) || address(groupToCircle[_entity]) != address(0),
            "Entity to be trusted must be a registered group or avatar."
        );
        _;
    }

    // Constructor

    constructor(
        IMintSplitter _mintSplitter,
        address _ancestorCircleMigrator,
        IAvatarCircleNode _masterCopyAvatarCircleNode,
        IGroupCircleNode _masterCopyGroupCircleNode
    ) {
        require(address(_mintSplitter) != address(0), "Mint Splitter contract must be provided.");
        // ancestorCircleMigrator can be zero and left unspecified. It simply disables migration.
        require(
            address(_masterCopyAvatarCircleNode) != address(0), "Mastercopy for Avatar Circle Node must not be zero."
        );
        require(address(_masterCopyGroupCircleNode) != address(0), "Mastercopy for Group Circle Node must not be zero.");

        mintSplitter = _mintSplitter;
        ancestorCircleMigrator = _ancestorCircleMigrator;
        masterCopyAvatarCircleNode = _masterCopyAvatarCircleNode;
        masterCopyGroupCircleNode = _masterCopyGroupCircleNode;

        // initialize the linked list for avatar circle nodes in the graph
        avatarCircleNodesIterable[IAvatarCircleNode(SENTINEL)] = IAvatarCircleNode(SENTINEL);
        // initialize the linked list for group circle nodes in the graph
        groupCircleNodesIterable[IGroupCircleNode(SENTINEL)] = IGroupCircleNode(SENTINEL);
        // initialize the linked list for organizations in the graph
        organizations[SENTINEL] = SENTINEL;
    }

    // External functions

    function registerAvatar() external notOnTrustGraph(msg.sender) {
        bytes memory avatarCircleNodeSetupData = abi.encodeWithSelector(AVATAR_CIRCLE_SETUP_CALLPREFIX, msg.sender);
        IAvatarCircleNode avatarCircleNode =
            IAvatarCircleNode(address(createProxy(address(masterCopyAvatarCircleNode), avatarCircleNodeSetupData)));

        avatarToCircle[msg.sender] = avatarCircleNode;
        _insertAvatarCircleNode(avatarCircleNode);

        _trust(msg.sender, msg.sender, INDEFINITELY);

        emit RegisterAvatar(msg.sender, address(avatarCircleNode));
    }

    function registerGroup(int128 _exitFee_64x64) external notOnTrustGraph(msg.sender) {
        // the correctness of the exit fee (0 <= fee <= 1) is checked in the setup()
        // of the group, so simply pass on the value here.
        bytes memory groupCircleNodeSetupData =
            abi.encodeWithSelector(GROUP_CIRCLE_SETUP_CALLPREFIX, msg.sender, _exitFee_64x64);
        IGroupCircleNode groupCircleNode =
            IGroupCircleNode(address(createProxy(address(masterCopyGroupCircleNode), groupCircleNodeSetupData)));

        groupToCircle[msg.sender] = groupCircleNode;
        _insertGroupCircleNode(groupCircleNode);

        _trust(msg.sender, msg.sender, INDEFINITELY);

        emit RegisterGroup(msg.sender, _exitFee_64x64);
    }

    function registerOrganization() external notOnTrustGraph(msg.sender) {
        _insertOrganization(msg.sender);

        emit RegisterOrganization(msg.sender);
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

    function untrust(address _entity) external onTrustGraph(msg.sender) canBeTrusted(_entity) {
        require(_entity != msg.sender, "Cannot edit your own trust relation.");
        // wait at least a full trust interval before the edge can expire
        uint256 earliestExpiry = ((block.timestamp / OPERATOR_INTERVAL) + 2) * OPERATOR_INTERVAL;

        require(getTrustExpiry(msg.sender, _entity) > earliestExpiry, "Trust is already set to (have) expire(d).");
        _upsertTrustMarker(msg.sender, _entity, uint96(earliestExpiry));

        emit Trust(msg.sender, _entity, earliestExpiry);
    }

    function authorizeGraphOperator(address _operator, uint256 _expiryAuthorization)
        external
        notOnTrustGraph(_operator)
    {
        uint256 currentOperatorInterval = block.timestamp / OPERATOR_INTERVAL;
        require(
            _expiryAuthorization >= (currentOperatorInterval + 1) * OPERATOR_INTERVAL,
            "Future expiry must be earliest in the next trust interval."
        );
        authorizedGraphOperators[msg.sender][_operator] = _expiryAuthorization;

        emit AuthorizedGraphOperator(msg.sender, _operator, _expiryAuthorization);
    }

    function revokeGraphOperator(address _operator) external onTrustGraph(msg.sender) notOnTrustGraph(_operator) {
        uint256 earliestExpiry = ((block.timestamp / OPERATOR_INTERVAL) + 2) * OPERATOR_INTERVAL;

        require(
            getGraphOperatorExpiry(msg.sender, _operator) > earliestExpiry, "Operator is already (set to be) revoked."
        );

        authorizedGraphOperators[msg.sender][_operator] = earliestExpiry;

        emit RevokedGraphOperator(msg.sender, _operator, earliestExpiry);
    }

    /**
     * Approve sets the global allowance for all Circle balances held by the caller.
     * The global allowance overrides any local allowances set (in the individual ERC20 contracts)
     * if it is called after an allowance for the same spender was set locally.
     * Conversely, if after setting a global allowance a local allowance value is set
     * in the ERC20 Circle contract, then that allowance overrides this global allowance.
     * If both local and global allowances are set in the same block, then the local allowance
     * overrides this global allowance.
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        require(_spender != address(0), "Spender for global approval must not be zero address.");

        globalAllowances[msg.sender][_spender] = _amount;
        // update the timestamp to know whether global or local allowance takes priority
        globalAllowanceTimestamps[msg.sender][_spender] = block.timestamp;

        emit GlobalApproval(msg.sender, _spender, _amount);

        return true;
    }

    function spendGlobalAllowance(address _entity, address _spender, uint256 _amount) external {
        // only a registered personal or group Circle contract can call this function
        // to spend from the global allowance
        require(
            address(avatarCircleNodesIterable[ICircleNode(msg.sender)]) != address(0)
                || address(groupCircleNodesIterable[ICircleNode(msg.sender)]) != address(0),
            "Only a registered Circle node can call to spend global allowance."
        );

        // note that any registered Circle node can spend from the global allowance
        // of the _entity, so msg.sender is not used for the state update
        uint256 remainingGlobalAllowance = globalAllowances[_entity][_spender] - _amount;
        globalAllowances[_entity][_spender] = remainingGlobalAllowance;

        // note to not update the timestamp from the global allowance as it gets spent.
    }

    function migrateCircles(address _owner, uint256 _amount, IAvatarCircleNode _circle)
        external
        onlyAncestorMigrator
        returns (uint256 migratedAmount_)
    {
        require(address(avatarCircleNodesIterable[_circle]) != address(0), "Circle is not registered in this graph.");
        return migratedAmount_ = _circle.migrate(_owner, _amount);
    }

    function fetchAllocation(address _avatar) external returns (int128 allocation_, uint256 earliestTimestamp_) {
        require(
            address(avatarCircleNodesIterable[ICircleNode(msg.sender)]) != address(0),
            "Only registered avatar circle nodes can request to fetch issuance allocation."
        );

        // reverse lookup to assert that the avatar circle contract
        // must always provide its own avatar address correctly.
        // (This could be an asert, but depends on deployment with a valid
        // master contract for avatar circles.)
        require(
            address(avatarToCircle[_avatar]) == msg.sender,
            "Provided avatar does not match for the calling avatar circle node."
        );

        // call on the mint splitter whether there is an allocation, and what the earliest timestamp is
        (allocation_, earliestTimestamp_) = mintSplitter.allocationTowardsCaller(_avatar);
        return (allocation_, earliestTimestamp_);
    }

    function checkAllAreTrustedCircleNodes(address _group, ICircleNode[] calldata _circles, bool _includeGroups)
        external
        view
        returns (bool allTrusted_)
    {
        require(
            address(groupCircleNodesIterable[ICircleNode(msg.sender)]) != address(0),
            "Caller must be a group circle node."
        );

        // reverse lookup to assert that the group circle contract
        // must always provide its own group correctly.
        // (This could be an asert, but depends on deployment with a valid
        // master contract for group circles.)
        require(
            address(groupToCircle[_group]) == msg.sender,
            "Provided group does not match for the calling group circle node."
        );

        if (_includeGroups) {
            // either avatar or group circles are valid
            for (uint256 i = 0; i < _circles.length; i++) {
                // entity for circle already reverts upon unregistered circle
                address entity = entityForCircleNode(_circles[i]);
                if (!isTrusted(_group, entity)) {
                    // don't require to let the caller decide how to handle query
                    return allTrusted_ = false;
                }
            }
        } else {
            // only avatar circles are valid
            for (uint256 i = 0; i < _circles.length; i++) {
                require(
                    address(avatarCircleNodesIterable[_circles[i]]) != address(0),
                    "Circle node is not known for an avatar on the graph."
                );
                address entity = _circles[i].entity();
                if (!isTrusted(_group, entity)) {
                    // don't require to let the caller decide how to handle query
                    return allTrusted_ = false;
                }
            }
        }

        return allTrusted_ = true;
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

        // verify the correctness of the flow matrix describing the path itself,
        // ie. well-definedness of the flow matrix itself,
        // check all entities are registered, and the trust relations are respected.
        int256[] memory verifiedNettedFlow = _verifyFlowMatrix(_flowVertices, _flow, coordinates, false);

        // match the equality of the intended flow with the verified path flow
        _matchNettedFlows(intendedNettedFlow, verifiedNettedFlow);

        // effectuate the actual path transfers
        // rely on revert upon underflow of balances to roll back
        // if any balance is insufficient
        _effectPathTranfers(_flowVertices, _flow, coordinates);
    }

    function operateFlowMatrix(
        int256[] calldata _intendedNettedFlow,
        address[] calldata _flowVertices,
        uint256[] calldata _flow,
        bytes calldata _packedCoordinates
    ) public {
        // first unpack the coordinates to array of uint16
        uint16[] memory coordinates = _unpackCoordinates(_packedCoordinates, _flow.length);

        require(
            _flowVertices.length == _intendedNettedFlow.length,
            "Length of intended flow must equal the number of vertices provided."
        );

        // check that all flow vertices have the calling operator enabled.
        require(isGraphOperatorForSet(msg.sender, _flowVertices), "Graph operator must be enabled for all vertices.");

        // if each vertex in the intended netted flow is zero, then it is a closed path
        bool closedPath = _checkClosedPath(_intendedNettedFlow);

        // verify the correctness of the flow matrix describing the path itself,
        // ie. well-definedness of the flow matrix itself,
        // check all entities are registered, and the trust relations are respected.
        int256[] memory verifiedNettedFlow = _verifyFlowMatrix(_flowVertices, _flow, coordinates, closedPath);

        // match the equality of the intended flow with the verified path flow
        _matchNettedFlows(_intendedNettedFlow, verifiedNettedFlow);

        // effectuate the actual path transfers
        // rely on revert upon underflow of balances to roll back
        // if any balance is insufficient
        _effectPathTranfers(_flowVertices, _flow, coordinates);
    }

    function isTrusted(address _truster, address _trusted)
        public
        view
        onTrustGraph(_truster)
        canBeTrusted(_trusted)
        returns (bool isTrusted_)
    {
        uint256 endOfCurrentTrustInterval = ((block.timestamp / OPERATOR_INTERVAL) + 1) * OPERATOR_INTERVAL;

        return isTrusted_ = getTrustExpiry(_truster, _trusted) >= endOfCurrentTrustInterval;
    }

    function getTrustExpiry(address _truster, address _trusted) public view returns (uint256 expiry_) {
        return expiry_ = uint256(trustMarkers[_truster][_trusted].expiry);
    }

    function isGraphOperator(address _entity, address _operator)
        public
        view
        onTrustGraph(_entity)
        notOnTrustGraph(_operator)
        returns (bool isGraphOperator_)
    {
        uint256 endOfCurrentOperatorInterval = ((block.timestamp / OPERATOR_INTERVAL) + 1) * OPERATOR_INTERVAL;

        return isGraphOperator_ = getGraphOperatorExpiry(_entity, _operator) >= endOfCurrentOperatorInterval;
    }

    function isGraphOperatorForSet(address _operator, address[] calldata _CircleNodes)
        public
        view
        returns (bool enabled_)
    {
        uint256 endOfCurrentOperatorInterval = ((block.timestamp / OPERATOR_INTERVAL) + 1) * OPERATOR_INTERVAL;

        for (uint256 i = 0; i < _CircleNodes.length; i++) {
            // if any Circle node has not currently enabled the operator it is disabled for thw whole set.
            // we don't check whether CircleNode is on the trust graph, because only valid address
            // can have enabled an operator.
            if (getGraphOperatorExpiry(_CircleNodes[i], _operator) < endOfCurrentOperatorInterval) {
                return enabled_ = false;
            }
        }

        return enabled_ = true;
    }

    function getGraphOperatorExpiry(address _entity, address _operator) public view returns (uint256 expiry_) {
        return expiry_ = authorizedGraphOperators[_entity][_operator];
    }

    function circleToAvatar(IAvatarCircleNode _node) public view returns (address avatar_) {
        // explicitly only look up possible avatars, do not return groups
        require(
            address(avatarCircleNodesIterable[_node]) != address(0), "Node is not registered as avatar on this graph."
        );
        return _node.entity();
    }

    function circleNodeForEntity(address _entity) public view canBeTrusted(_entity) returns (ICircleNode circleNode_) {
        // first see if the entity is a registered avatar
        circleNode_ = avatarToCircle[_entity];
        if (address(circleNode_) != address(0)) {
            return circleNode_;
        }
        // we already check this in modifier, by exclusion. Leave this here during development.
        assert(address(groupToCircle[_entity]) != address(0));
        // return the group itself as the circle node
        assert(false); // todo: not yet implemented, think proper about group currencies
        return ICircleNode(_entity);
    }

    function entityForCircleNode(ICircleNode _circleNode) public view returns (address entity_) {
        require(
            address(avatarCircleNodesIterable[_circleNode]) != address(0)
                || address(groupCircleNodesIterable[_circleNode]) != address(0),
            "Circle node is not known on the graph."
        );

        entity_ = _circleNode.entity();
        assert(entity_ != address(0));
        return entity_;
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
    ) internal view returns (int256[] memory nettedFlow_) {
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
                address(avatarToCircle[entity]) != address(0) || address(organizations[entity]) != address(0)
                    || address(groupToCircle[entity]) != address(0),
                "Flow vertex is neither a registered organisation, group or avatar."
            );
        }
        // don't miss checking the last vertex for registration on the graph
        address lastEntity = _flowVertices[_flowVertices.length - 1];
        require(
            address(avatarToCircle[lastEntity]) != address(0) || address(organizations[lastEntity]) != address(0)
                || address(groupToCircle[lastEntity]) != address(0),
            "Flow vertex is neither a registered organisation, group or avatar."
        );

        // iterate over the coordinate index
        uint16 index = uint16(0);

        // iterate over all flow edges in the path
        for (uint256 i = 0; i < _flow.length; i++) {
            // retrieve the flow vertices associated with this flow edge
            address tokenEntity = _flowVertices[_coordinates[index++]];
            uint16 fromIndex = index++;
            uint16 toIndex = index++;
            address to = _flowVertices[_coordinates[toIndex]];
            // cast the flow amount from uint256 to int256,
            // will revert if flow is larger than type(int256).max
            int256 flow = int256(_flow[i]);

            // check receiver is within the trust circle of the token being sent
            require(isTrusted(to, tokenEntity), "The receiver does not trust the token being sent in the flow edge.");
            require(
                !_cleanupClosedPath || (to == tokenEntity && address(groupToCircle[to]) == address(0)),
                "For closed paths, tokens may only be sent to original avatar, and exclude group tokens."
            );

            // nett the flow across tokens
            nettedFlow_[_coordinates[fromIndex]] -= flow;
            nettedFlow_[_coordinates[toIndex]] += flow;
        }

        return nettedFlow_;
    }

    function _matchNettedFlows(int256[] memory _intendedNettedFlow, int256[] memory _verifiedNettedFlow)
        internal
        pure
    {
        assert(_intendedNettedFlow.length == _verifiedNettedFlow.length);
        for (uint256 i = 0; i < _intendedNettedFlow.length; i++) {
            require(_intendedNettedFlow[i] == _verifiedNettedFlow[i], "Intended flow does not match verified flow.");
        }
    }

    /**
     * @dev Cricital: effect transfer assumes that all the validity checks have been performed,
     *      and passed; it will simply execute the transfers, so any caller MUST ensure
     *      instructions passed in are valid to execute.
     */
    function _effectPathTranfers(
        address[] calldata _flowVertices,
        uint256[] calldata _flow,
        uint16[] memory _coordinates
    ) internal {
        // track the three coordinate indices per flow edge
        uint16 index = uint16(0);

        // for each flow effectuate the transfers
        for (uint256 i = 0; i < _flow.length; i++) {
            // retrieve the flow vertices associated with this flow edge
            address tokenEntity = _flowVertices[_coordinates[index++]];
            uint16 fromIndex = index++;
            address from = _flowVertices[_coordinates[fromIndex]];
            uint16 toIndex = index++;
            address to = _flowVertices[_coordinates[toIndex]];

            ICircleNode node = circleNodeForEntity(tokenEntity);

            node.pathTransfer(from, to, _flow[i]);
        }
    }

    function _checkClosedPath(int256[] calldata _intendedFlow) internal pure returns (bool closedPath_) {
        // start by assuming it is a closed path
        closedPath_ = true;

        for (uint256 i = 0; i < _intendedFlow.length; i++) {
            // then any non-zero intentedFlow value, breaks the closed path open
            closedPath_ = closedPath_ && (_intendedFlow[i] == int256(0));
        }

        return closedPath_;
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

    function _trust(address _truster, address _trusted, uint256 _expiryTrustMarker) internal {
        // take the floor of current timestamp to get current interval
        uint256 currentTrustInterval = block.timestamp / OPERATOR_INTERVAL;
        require(
            _expiryTrustMarker >= (currentTrustInterval + 1) * OPERATOR_INTERVAL,
            "Future expiry must be earliest in the next trust interval."
        );
        // trust can instantly be registered
        _upsertTrustMarker(_truster, _trusted, uint96(_expiryTrustMarker));

        emit Trust(_truster, _trusted, _expiryTrustMarker);
    }

    // Private functions

    function _upsertTrustMarker(address _truster, address _trusted, uint96 _expiryTrustMarker) private {
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
        trustMarker.expiry = _expiryTrustMarker;
    }

    function _insertAvatarCircleNode(IAvatarCircleNode _avatarCircleNode) private {
        assert(address(_avatarCircleNode) != address(0));
        assert(_avatarCircleNode != IAvatarCircleNode(SENTINEL));
        assert(address(avatarCircleNodesIterable[_avatarCircleNode]) == address(0));

        // the linked list for avatar circle nodes is initialized in the constructor

        // prepend the new AvatarCircleNode in the iterable linked list
        avatarCircleNodesIterable[_avatarCircleNode] = avatarCircleNodesIterable[ICircleNode(SENTINEL)];
        avatarCircleNodesIterable[ICircleNode(SENTINEL)] = _avatarCircleNode;
    }

    function _insertGroupCircleNode(IGroupCircleNode _groupCircleNode) private {
        assert(address(_groupCircleNode) != address(0));
        assert(_groupCircleNode != IGroupCircleNode(SENTINEL));
        assert(address(groupCircleNodesIterable[_groupCircleNode]) == address(0));

        // the linked list for group circle nodes is initialized in the constructor

        // prepend the new GroupCircleNode in the iterable linked list
        groupCircleNodesIterable[_groupCircleNode] = groupCircleNodesIterable[ICircleNode(SENTINEL)];
        groupCircleNodesIterable[ICircleNode(SENTINEL)] = _groupCircleNode;
    }

    function _insertOrganization(address _organization) private {
        assert(_organization != address(0));
        assert(_organization != SENTINEL);
        assert(organizations[_organization] != address(0));

        // the linked list for organization addresses is initialized in the constructor

        organizations[_organization] = organizations[SENTINEL];
        organizations[SENTINEL] = _organization;
    }
}
