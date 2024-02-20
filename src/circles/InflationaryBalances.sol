// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../lib/Math64x64.sol";

// todo: this contract is incomplete, deprecated and will be removed. It was useful to determine that storing the inflationary balances is not the right approach.
contract InflationaryBalances {
    // Constants

    /**
     * @notice Demurrage window reduces the resolution for calculating
     * the demurrage of balances from once per second (block.timestamp)
     * to once per day.
     */
    uint256 public constant DEMURRAGE_WINDOW = 1 days;

    /**
     * @dev Reduction factor GAMMA for applying demurrage to balances
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
    int128 internal constant GAMMA_64x64 = int128(18443079296116538654);

    /**
     * @dev For calculating the inflationary mint amount on day `d`
     * since demurrage_day_zero, a person can mint
     *   (1/GAMMA)^d CRC / hour
     * As GAMMA is a constant, to save gas costs store the inverse
     * as BETA = 1 / GAMMA.
     * BETA_64x64 is the 64.64 fixed point representation:
     *   BETA_64x64 = 2**64 / ((0.93)^(1/365.25))
     *              = 18450409579521241655
     * For more details, see ./specifications/TCIP009-demurrage.md
     */
    int128 internal constant BETA_64x64 = int128(18450409579521241655);

    /**
     * @dev ERC1155 tokens MUST be 18 decimals.
     */
    uint8 internal constant DECIMALS = uint8(18);

    /**
     * @dev EXA factor as 10^18
     */
    uint256 internal constant EXA = uint256(10 ** DECIMALS);

    /**
     * @dev Store the signed 128-bit 64.64 representation of 1 as a constant
     */
    int128 internal constant ONE_64x64 = int128(2 ** 64);

    /**
     * @dev Store all amounts privately with an additional precision by left
     * shifting by 14 bits (2**14 = 16.384).
     */
    uint256 private constant EXTRA_PRECISION = uint256(14);

    uint256 private constant MAX_VALUE = uint256(2 ** 242 - 1);

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
     * @dev stores the balances of the accounts privately in a custom format to increase
     * the numerical precision such that conversion between demurrage and inflationary units
     * can be done reversibly without loss of precision.
     */
    mapping(uint256 id => mapping(address account => uint256 balance)) private balances;

    /**
     * @dev Store a lookup table T(n) for computing issuance.
     * See ../../specifications/TCIP009-demurrage.md for more details.
     */
    int128[15] internal T = [
        int128(442721857769029238784),
        int128(885355760875826166476),
        int128(1327901726794166863126),
        int128(1770359772994355928788),
        int128(2212729916943227173193),
        int128(2655012176104144305282),
        int128(3097206567937001622606),
        int128(3539313109898224700583),
        int128(3981331819440771081628),
        int128(4423262714014130964135),
        int128(4865105811064327891331),
        int128(5306861128033919439986),
        int128(5748528682361997908993),
        int128(6190108491484191007805),
        int128(6631600572832662544739)
    ];

    /**
     * @dev Store a lookup table R(n) for computing issuance.
     * See ../../specifications/TCIP009-demurrage.md for more details.
     */
    int128[15] internal R = [
        int128(18446744073709551616),
        int128(18443079296116538654),
        int128(18439415246597529027),
        int128(18435751925007877736),
        int128(18432089331202968517),
        int128(18428427465038213837),
        int128(18424766326369054888),
        int128(18421105915050961582),
        int128(18417446230939432544),
        int128(18413787273889995104),
        int128(18410129043758205300),
        int128(18406471540399647861),
        int128(18402814763669936209),
        int128(18399158713424712450),
        int128(18395503389519647372)
    ];

    /**
     * @dev Cache computation of inflation factor and demurrage factor
     */
    int128 private cacheInflationFactor;
    int128 private cacheDemurrageFactor;
    uint256 private cacheInflationFactorDay;
    uint256 private cacheDemurrageFactorDay;

    // Constructor

    constructor(uint256 _demurrage_day_zero) {
        demurrage_day_zero = _demurrage_day_zero;
    }

    // Public functions

    /**
     * @notice update the inflation factor for today if not already cached
     */
    function updateTodaysInflationFactor() public returns (int128, uint256) {
        uint256 today = day(block.timestamp);
        assert(today > 0);
        if (cacheInflationFactorDay == today) {
            return (cacheInflationFactor, today);
        } else {
            int128 inflationFactor = Math64x64.pow(BETA_64x64, today);
            cacheInflationFactor = inflationFactor;
            cacheInflationFactorDay = today;
            return (inflationFactor, today);
        }
    }

    /**
     * @notice Get today's inflation factor.
     * @return Returns the inflation factor
     * @return Returns the day number since day zero for the current day.
     */
    function todaysInflationFactor() public view returns (int128, uint256) {
        uint256 today = day(block.timestamp);
        assert(today > 0);
        if (cacheInflationFactorDay == today) {
            return (cacheInflationFactor, today);
        } else {
            // calculate the inflation factor for today if not cached
            int128 inflationFactor = Math64x64.pow(BETA_64x64, today);
            // but don't update the cache because we want to preserve the `view` function
            return (inflationFactor, today);
        }
    }

    /**
     * @notice Calculate the day since demurrage_day_zero for a given timestamp.
     * @param _timestamp Timestamp for which to calculate the day since
     * demurrage_day_zero.
     */
    function day(uint256 _timestamp) public view returns (uint256) {
        // calculate which day the timestamp is in, rounding down
        return (_timestamp - demurrage_day_zero) / DEMURRAGE_WINDOW;
    }

    /**
     * @notice Casts an avatar address to a tokenId uint256.
     * @param _avatar avatar address to convert to tokenId
     */
    function toTokenId(address _avatar) public pure returns (uint256) {
        return uint256(uint160(_avatar));
    }

    // Internal functions

    /**
     * @dev BalanceOf returns the demurraged balance for a requested Circles identifier.
     * @param _account Address of the account for which to view the demurraged balance.
     * @param _id Cirlces identifier for which to the check the balance.
     */
    function _balanceOf(address _account, uint256 _id) internal view returns (uint256) {
        uint256 inflationaryShiftedBalance = balances[_id][_account];
        // todo: similarly, cache this daily factor upon transfer (keep balanceOf a view function)
        int128 demurrageFactor = Math64x64.pow(GAMMA_64x64, day(block.timestamp));
        uint256 demurrageShiftedBalance = Math64x64.mulu(demurrageFactor, inflationaryShiftedBalance);
        // shift back to normal precision
        return demurrageShiftedBalance >> EXTRA_PRECISION;
    }

    function _updateBalance(address _account, uint256 _id, uint256 _value) internal {
        require(_value < MAX_VALUE, "Balances: value exceeds maximum value of uint242");
        // shift value for extra precision
        uint256 shiftedValue = _value << EXTRA_PRECISION;
        int128 inverseInflationaryFactor = Math64x64.pow(BETA_64x64, day(block.timestamp));
        uint256 inflationaryShiftedValue = Math64x64.mulu(inverseInflationaryFactor, shiftedValue);
        balances[_id][_account] = inflationaryShiftedValue;
    }
}
