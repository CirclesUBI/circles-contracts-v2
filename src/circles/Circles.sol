// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./ERC1155.sol";
import "./ICircles.sol";
import "../lib/Math64x64.sol";

contract Circles is ERC1155, ICircles {
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
     * @dev Address used to indicate that the associated v1 Circles contract has been stopped.
     */
    address public constant CIRCLES_STOPPED_V1 = address(0x1);

    /**
     * @notice Indefinite future, or approximated with uint96.max
     */
    uint96 public constant INDEFINITE_FUTURE = type(uint96).max;

    // State variables

    /**
     * @notice The mapping of avatar addresses to the last mint time,
     * and the status of the v1 Circles minting.
     * @dev This is used to store the last mint time for each avatar.
     */
    mapping(address => MintTime) public mintTimes;

    // Events

    // Constructor

    /**
     * Constructor to create a Circles ERC1155 contract with demurrage.
     * @param _inflation_day_zero Inflation day zero stores the start of the global inflation curve
     * @param _uri uri for the Circles metadata
     */
    constructor(uint256 _inflation_day_zero, string memory _uri)
        ERC1155(_uri)
        DiscountedBalances(_inflation_day_zero)
    {}

    // External functions

    // Public functions

    /**
     * @notice Calculate the demurraged issuance for a human's avatar.
     * @param _human Address of the human's avatar to calculate the issuance for.
     */
    function calculateIssuance(address _human) public view returns (uint256) {
        MintTime storage mintTime = mintTimes[_human];
        require(
            mintTime.mintV1Status == address(0) || mintTime.mintV1Status == CIRCLES_STOPPED_V1,
            "Circles v1 contract cannot be active."
        );

        if (uint256(mintTime.lastMintTime) + 10 > block.timestamp) {
            // Mint time is set to indefinite future for stopped mints in v2
            // and wait at least 10 seconds between mints
            return 0;
        }

        // calculate the start of the claimable period
        uint256 startMint = _max(block.timestamp - MAX_CLAIM_DURATION, mintTime.lastMintTime);

        // day of start of mint, dA
        uint256 dA = uint256(day(startMint));

        // day of current block, dB
        uint256 dB = uint256(day(block.timestamp));

        // the difference of days between dB and dA used for the table lookups
        uint256 n = dB - dA;

        // calculate the number of completed hours in day A until `startMint`
        int128 k = Math64x64.fromUInt((startMint - (dA * 1 days + inflation_day_zero)) / 1 hours);

        // Calculate the number of incompleted hours remaining in day B from current timestamp
        int128 l = Math64x64.fromUInt(((dB + 1) * 1 days + inflation_day_zero - block.timestamp) / 1 hours + 1);

        // calculate the overcounted (demurraged) k (in day A) and l (in day B) hours
        int128 overcount = Math64x64.add(Math64x64.mul(R[n], k), l);

        // subtract the overcount from the total issuance, and convert to attoCircles
        return Math64x64.mulu(Math64x64.sub(T[n], overcount), EXA);
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
        _mint(_human, toTokenId(_human), issuance, "");
        // update the last mint time
        mintTimes[_human].lastMintTime = uint96(block.timestamp);
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
