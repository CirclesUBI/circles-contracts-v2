// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

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
     * @notice Issue one Circle per hour for each human.
     */
    uint256 public constant ISSUANCE_PERIOD = 1 hours;

    /**
     * @notice Upon claiming, the maximum claim is upto two weeks
     * of history. Unclaimed older Circles are unclaimable.
     */
    uint256 public constant MAX_CLAIM_DURATION = 2 weeks;

    // /**
    //  * @notice The timestamp of the start of the Circles v1 contract.
    //  * Thursday 15th October 2020 at 6:25:30 pm UTC
    //  * @dev This is used as the global offset to calculate the demurrage,
    //  * or equivalently the inflationary mint of Circles.
    //  */
    // uint256 public constant CIRCLES_START_TIME = uint256(1602786330);

    // /**
    //  * @notice The original Hub v1 contract was deployed on Thursday 15th October 2020 at 6:25:30 pm UTC.
    //  * So to reset the global demurrage window to midnight, an offset of 66330 seconds is subtracted to
    //  * have the start of day zero, for which the original mint was 1 CRC per hour.
    //  */
    // uint256 public constant DEMURRAGE_DAY_ZERO = CIRCLES_START_TIME - uint256(66330);

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
     * @dev ERC1155 tokens MUST be 18 decimals. Used to calculate the issuance rate.
     */
    uint8 public constant DECIMALS = uint8(18);

    /**
     * @dev EXA factor as 10^18
     */
    uint256 internal constant EXA = uint256(10 ** 18);

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

    // Internal functions

    function _claimIssuance() internal {}

    function _calculateIssuance(address _human) internal returns (uint256) {
        MintTime storage mintTime = mintTimes[_human];
        require(
            mintTime.mintV1Status == address(0) || mintTime.mintV1Status == CIRCLES_STOPPED_V1,
            "Circles v1 contract cannot be active."
        );

        uint256 hoursSinceLastMint = (block.timestamp - mintTime.lastMintTime) / ISSUANCE_PERIOD;
    }

    function _updateMintV1Status(address _human, address _mintV1Status) internal {
        MintTime storage mintTime = mintTimes[_human];
        // precautionary check to ensure that the last mint time is already set
        // as this marks whether an avatar is registered as human or not
        assert(mintTime.lastMintTime > 0);
        // if the status has changed, update the last mint time
        // to avoid possible overlap of the mint between Hub v1 and Hub v2
        if (mintTime.mintV1Status != _mintV1Status) {
            mintTime.mintV1Status = _mintV1Status;
            mintTime.lastMintTime = uint96(block.timestamp);
        }
    }

    function _dailyIssuance(uint256 _timestamp) internal view returns (uint256) {
        // first calculate which day the timestamp is in, rounding down
        uint256 day = (_timestamp - demurrage_day_zero) / DEMURRAGE_WINDOW;

        // then calculate the issuance for that day
    }
}
