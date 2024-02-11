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

    // Constructor

    constructor(uint256 _demurrage_day_zero, string memory _uri) ERC1155(_uri) {
        demurrage_day_zero = _demurrage_day_zero;
    }

    // External functions

    // Public functions

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
            int128 term1 = iB1 - ONE_64x64;
            int128 term2 = iA - ONE_64x64;
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
