// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../lib/Math64x64.sol";

contract Circles is ERC1155 {
    // Type declarations

    /**
     * @notice MintTime struct stores the last mint time,
     * and the status of a connected v1 Circles contract.
     * @dev This is used to store the last mint time for each avatar,
     * and the address is used as a status for the connected v1 Circles contract.
     * The address is kept at zero address if the avatar is not registered in Hub v1.
     * If the avatar is registered in Hub v1, but the associated Circles ERC20 contract
     * has not been stopped, then the address is set to that v1 Circles contract address.
     * Once the Circles v1 contract has been stopped, the address is set to 0x01.
     * At every observed transition of the status of the v1 Circles contract,
     * the lastMintTime will be updated to the current timestamp to avoid possible
     * overlap of the mint between Hub v1 and Hub v2.
     */
    struct MintTime {
        address mintV1Status;
        uint96 lastMintTime;
    }

    // Constants

    /**
     * @notice Issue one Circle per hour for each human in demurraged units.
     * So per second issue 10**18 / 3600 = 277777777777778 attoCircles.
     */
    uint256 public constant ISSUANCE_PER_SECOND = uint256(277777777777778);

    /**
     * @notice Upon claiming, the maximum claim is upto two weeks
     * of history. Unclaimed older Circles are unclaimable.
     */
    uint256 public constant MAX_CLAIM_DURATION = 2 weeks;

    /**
     * @notice Demurrage window reduces the resolution for calculating
     * the demurrage of balances from once per second (block.timestamp)
     * to once per day.
     */
    uint256 public constant DEMURRAGE_WINDOW = 1 days;

    /**
     * @notice Reduction factor GAMMA for applying demurrage to balances
     *   demurrage_balance(d) = GAMMA^d * inflationary_balance
     * where 'd' is expressed in days (DEMURRAGE_WINDOW) since demurrage_day_zero,
     * and GAMMA < 1.
     * GAMMA_64x64 stores the numerator for the signed 128bit 64.64
     * fixed decimal point expression:
     *   GAMMA = GAMMA_64x64 / 2**64.
     * To obtain GAMMA for a daily accounting of 7% p.a. demurrage
     *   => GAMMA = (0.93)^(1/365.25)
     *            = 0.99980133200859895743...
     * and expressed in 64.64 fixed point representation:
     *   => GAMMA_64x64 = 18443079296116538654
     * For more details, see ./specifications/TCIP009-demurrage.md
     */
    int128 public constant GAMMA_64x64 = int128(18443079296116538654);

    /**
     * @notice For calculating the inflationary mint amount on day `d`
     * since demurrage_day_zero, a person can mint
     *   (1/GAMMA)^d CRC / hour
     * As GAMMA is a constant, to save gas costs store the inverse
     * as BETA = 1 / GAMMA.
     * BETA_64x64 is the 64.64 fixed point representation:
     *   BETA_64x64 = 2**64 / ((0.93)^(1/365.25))
     *              = 18450409579521241655
     * For more details, see ./specifications/TCIP009-demurrage.md
     */
    int128 public constant BETA_64x64 = int128(18450409579521241655);

    /**
     * @dev Address used to indicate that the associated v1 Circles contract has been stopped.
     */
    address public constant CIRCLES_STOPPED_V1 = address(0x1);

    /**
     * @notice Indefinite future, or approximated with uint96.max
     */
    uint96 public constant INDEFINITE_FUTURE = type(uint96).max;

    /**
     * @dev ERC1155 tokens MUST be 18 decimals.
     */
    uint8 public constant DECIMALS = uint8(18);

    /**
     * @dev EXA factor as 10^18
     */
    uint256 internal constant EXA = uint256(10 ** DECIMALS);

    /**
     * Store the signed 128-bit 64.64 representation of 1 as a constant
     */
    int128 internal constant ONE_64x64 = int128(2 ** 64);

    // State variables

    /**
     * @notice Demurrage day zero stores the start of the global demurrage curve
     * As Circles Hub v1 was deployed on Thursday 15th October 2020 at 6:25:30 pm UTC,
     * or 1602786330 unix time, in production this value MUST be set to 1602720000 unix time,
     * or midnight prior of the same day of deployment, marking the start of the first day
     * where there was no inflation on one CRC per hour.
     */
    uint256 public immutable demurrage_day_zero;

    /**
     * @notice The mapping of avatar addresses to the last mint time,
     * and the status of the v1 Circles minting.
     * @dev This is used to store the last mint time for each avatar.
     */
    mapping(address => MintTime) public mintTimes;

    // Events

    /**
     * @dev Emitted when Circles are transferred in addition to TransferSingle event,
     * to include the demurraged value of the Circles transferred.
     * @param operator Operator who called safeTransferFrom.
     * @param from Address from which the Circles have been transferred.
     * @param to Address to which the Circles have been transferred.
     * @param id Circles identifier for which the Circles have been transferred.
     * @param value Demurraged value of the Circles transferred.
     * @param inflationaryValue Inflationary amount of Circles transferred.
     */
    event DemurragedTransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value,
        uint256 inflationaryValue
    );

    /**
     * @dev Emitted when Circles are transferred in addition to TransferBatch event,
     * to include the demurraged values of the Circles transferred.
     * @param operator Operator who called safeBatchTransferFrom.
     * @param from Address from which the Circles have been transferred.
     * @param to Address to which the Circles have been transferred.
     * @param ids Array of Circles identifiers for which the Circles have been transferred.
     * @param values Array of demurraged values of the Circles transferred.
     * @param inflationaryValues Array of inflationary amounts of Circles transferred.
     */
    event DemurragedTransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values,
        uint256[] inflationaryValues
    );

    // Constructor

    constructor(uint256 _demurrage_day_zero, string memory _uri) ERC1155(_uri) {
        demurrage_day_zero = _demurrage_day_zero;
    }

    // External functions

    // Public functions

    /**
     * @notice BalanceOf returns the demurraged balance for a requested Circles identifier.
     * @param _account Address of the account for which to view the demurraged balance.
     * @param _id Cirlces identifier for which to the check the balance.
     */
    function balanceOf(address _account, uint256 _id) public view override returns (uint256) {
        uint256 inflationaryBalance = super.balanceOf(_account, _id);
        // todo: similarly, cache this daily factor upon transfer (keep balanceOf a view function)
        int128 demurrageFactor = Math64x64.pow(GAMMA_64x64, _day(block.timestamp));
        uint256 demurrageBalance = Math64x64.mulu(demurrageFactor, inflationaryBalance);
        return demurrageBalance;
    }

    /**
     * @notice BalanceOfBatch returns the balances of a batch request for given accounts and Circles identifiers.
     * @param _accounts Batch of addreses of the accounts for which to view the demurraged balances.
     * @param _ids Batch of Circles identifiers for which to check the balances.
     */
    function balanceOfBatch(address[] memory _accounts, uint256[] memory _ids)
        public
        view
        override
        returns (uint256[] memory)
    {
        // ERC1155.sol already checks for equal lenght of arrays
        // get the inflationary balances as a batch
        uint256[] memory batchBalances = super.balanceOfBatch(_accounts, _ids);
        int128 demurrageFactor = Math64x64.pow(GAMMA_64x64, _day(block.timestamp));
        for (uint256 i = 0; i < _accounts.length; i++) {
            // convert from inflationary balances to demurraged balances
            // mutate the balances in place to save memory
            batchBalances[i] = Math64x64.mulu(demurrageFactor, batchBalances[i]);
        }
        return batchBalances;
    }

    /**
     * @notice safeTransferFrom transfers Circles from one address to another in demurrage units.
     * @param _from Address from which the Circles are transferred.
     * @param _to Address to which the Circles are transferred.
     * @param _id Circles indentifier for which the Circles are transferred.
     * @param _value Demurraged value of the Circles transferred.
     * @param _data Data to pass to the receiver.
     */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes memory _data)
        public
        override
    {
        // the `value` parameter is expressed in demurraged units,
        // so it needs to be converted to inflationary units first
        // todo: again, cache this daily factor upon transfer
        int128 inflationaryFactor = Math64x64.pow(BETA_64x64, _day(block.timestamp));
        uint256 inflationaryValue = Math64x64.mulu(inflationaryFactor, _value);
        super.safeTransferFrom(_from, _to, _id, inflationaryValue, _data);

        emit DemurragedTransferSingle(msg.sender, _from, _to, _id, _value, inflationaryValue);
    }

    /**
     * @notice safeBatchTransferFrom transfers Circles from one address to another in demurrage units.
     * @param _from Address from which the Circles are transferred.
     * @param _to Address to which the Circles are transferred.
     * @param _ids Batch of Circles identifiers for which the Circles are transferred.
     * @param _values Batch of demurraged values of the Circles transferred.
     * @param _data Data to pass to the receiver.
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory _data
    ) public override {
        // the `_values` parameter is expressed in demurraged units,
        // so it needs to be converted to inflationary units first
        int128 inflationaryFactor = Math64x64.pow(BETA_64x64, _day(block.timestamp));
        uint256[] memory inflationaryValues = new uint256[](_values.length);
        for (uint256 i = 0; i < _values.length; i++) {
            inflationaryValues[i] = Math64x64.mulu(inflationaryFactor, _values[i]);
        }
        super.safeBatchTransferFrom(_from, _to, _ids, inflationaryValues, _data);

        emit DemurragedTransferBatch(msg.sender, _from, _to, _ids, _values, inflationaryValues);
    }

    /**
     * @notice inflationarySafeTransferFrom transfers Circles from one address to another in inflationary units.
     * @param _from Address from which the Circles are transferred.
     * @param _to Address to which the Circles are transferred.
     * @param _id Circles indentifier for which the Circles are transferred.
     * @param _value Inflationary value of the Circles transferred.
     * @param _data Data to pass to the receiver.
     */
    function inflationarySafeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes memory _data)
        public
    {
        super.safeTransferFrom(_from, _to, _id, _value, _data);
    }

    /**
     * @notice inflationarySafeBatchTransferFrom transfers Circles from one address to another in inflationary units.
     * @param _from Address from which the Circles are transferred.
     * @param _to Address to which the Circles are transferred.
     * @param _ids Batch of Circles identifiers for which the Circles are transferred.
     * @param _values Batch of inflationary values of the Circles transferred.
     * @param _data Data to pass to the receiver.
     */
    function inflationarySafeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory _data
    ) public {
        super.safeBatchTransferFrom(_from, _to, _ids, _values, _data);
    }

    /**
     * @notice Burn Circles in demurrage units.
     * @param _id Circles identifier for which to burn the Circles.
     * @param _value Demurraged value of the Circles to burn.
     */
    function burn(uint256 _id, uint256 _value) public {
        int128 inflationaryFactor = Math64x64.pow(BETA_64x64, _day(block.timestamp));
        uint256 inflationaryValue = Math64x64.mulu(inflationaryFactor, _value);
        super._burn(msg.sender, _id, inflationaryValue);
    }

    /**
     * @notice Burn a batch of Circles in demurrage units.
     * @param _ids Batch of Circles identifiers for which to burn the Circles.
     * @param _values Batch of demurraged values of the Circles to burn.
     */
    function burnBatch(uint256[] memory _ids, uint256[] memory _values) public {
        int128 inflationaryFactor = Math64x64.pow(BETA_64x64, _day(block.timestamp));
        uint256[] memory inflationaryValues = new uint256[](_values.length);
        for (uint256 i = 0; i < _values.length; i++) {
            inflationaryValues[i] = Math64x64.mulu(inflationaryFactor, _values[i]);
        }
        super._burnBatch(msg.sender, _ids, inflationaryValues);
    }

    /**
     * @notice Burn Circles in inflationary units.
     * @param _id Circles identifier for which to burn the Circles.
     * @param _value Value of the Circles to burn in inflationary units.
     */
    function inflationaryBurn(uint256 _id, uint256 _value) public {
        super._burn(msg.sender, _id, _value);
    }

    /**
     * @notice Burn a batch of Circles in inflationary units.
     * @param _ids Batch of Circles identifiers for which to burn the Circles.
     * @param _values Batch of values of the Circles to burn in inflationary units.
     */
    function inflationaryBurnBatch(uint256[] memory _ids, uint256[] memory _values) public {
        super._burnBatch(msg.sender, _ids, _values);
    }

    /**
     * @notice Calculate the issuance for a human's avatar.
     * @param _human Address of the human's avatar to calculate the issuance for.
     */
    function calculateIssuance(address _human) public view returns (uint256) {
        MintTime storage mintTime = mintTimes[_human];
        require(
            mintTime.mintV1Status == address(0) || mintTime.mintV1Status == CIRCLES_STOPPED_V1,
            "Circles v1 contract cannot be active."
        );

        if (uint256(mintTime.lastMintTime) + 1 hours >= block.timestamp) {
            // Mint time is set to indefinite future for stopped mints in v2
            // and wait at least one hour for a minimal mint issuance
            return 0;
        }

        // calculate the start of the claimable period
        uint256 startMint = _max(block.timestamp - MAX_CLAIM_DURATION, mintTime.lastMintTime);

        // day of start of mint, dA
        uint256 dA = _day(startMint);
        // day of end of mint (now), dB
        uint256 dB = _day(block.timestamp);

        // todo: later cache these computations, as they roll through a window of 15 days/values
        // because there is a max claimable window, and once filled, only once per day we need to calculate
        // a new value in the cache for all mints.

        // iA = Beta^dA
        int128 iA = Math64x64.pow(BETA_64x64, dA);
        // iB = Beta^dB
        int128 iB = 0;
        if (dA == dB) {
            // if the start and end day are the same, then the issuance factor is the same
            iB = iA;
        } else {
            iB = Math64x64.pow(BETA_64x64, dB);
        }
        uint256 fullIssuance = 0;
        {
            // for the geometric sum we need Beta^(dB + 1) = iB1
            int128 iB1 = Math64x64.mul(iB, BETA_64x64);

            // first calculate the full issuance over the complete days [dA, dB]
            // using the geometric sum:
            //   SUM_i=dA..dB (Beta^i) = (Beta^(dB + 1) - 1) / (Beta^dA - 1)
            int128 term1 = Math64x64.sub(iB1, ONE_64x64);
            int128 term2 = Math64x64.sub(iA, ONE_64x64);
            int128 geometricSum = Math64x64.div(term1, term2);
            // 24 hours * 1 CRC/hour * EXA * geometricSum
            fullIssuance = Math64x64.mulu(geometricSum, 24 * EXA);
        }

        // But now we overcounted, as we start day A at startMint
        // and end day B at block.timestamp, so we need to adjust
        uint256 overcountA = startMint - (dA * 1 days + demurrage_day_zero);
        uint256 overcountB = (dB + 1) * 1 days + demurrage_day_zero - block.timestamp;

        uint256 overIssuanceA = Math64x64.mulu(iA, overcountA * ISSUANCE_PER_SECOND);
        uint256 overIssuanceB = Math64x64.mulu(iB, overcountB * ISSUANCE_PER_SECOND);

        // subtract the overcounted issuance
        uint256 issuance = fullIssuance - overIssuanceA - overIssuanceB;

        return issuance;
    }

    // Internal functions

    /**
     * @notice Claim issuance for a human's avatar and update the last mint time.
     * @param _human Address of the human's avatar to claim the issuance for.
     */
    function _claimIssuance(address _human) internal {
        uint256 issuance = calculateIssuance(_human);
        require(issuance > 0, "No issuance to claim.");
        // mint personal Circles to the human
        _mint(_human, _toTokenId(_human), issuance, "");

        // update the last mint time
        mintTimes[_human].lastMintTime = uint96(block.timestamp);
    }

    /**
     * @dev Calculate the day since demurrage_day_zero for a given timestamp.
     * @param _timestamp Timestamp for which to calculate the day since
     * demurrage_day_zero.
     */
    function _day(uint256 _timestamp) internal view returns (uint256) {
        // calculate which day the timestamp is in, rounding down
        return (_timestamp - demurrage_day_zero) / DEMURRAGE_WINDOW;
    }

    /**
     * @dev Casts an avatar address to a tokenId uint256.
     * @param _avatar avatar address to convert to tokenId
     */
    function _toTokenId(address _avatar) internal pure returns (uint256) {
        return uint256(uint160(_avatar));
    }

    // Private functions

    /**
     * @dev Max function to compare two values.
     * @param a Value a
     * @param b Value b
     */
    function _max(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? a : b;
    }
}
