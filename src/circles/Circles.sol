// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "./ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
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

    function inflationaryBalanceOf(address _account, uint256 _id) public view returns (uint256) {
        assert(false);
        return 0;
    }

    function inflationaryBalanceOfBatch(address[] memory _accounts, uint256[] memory _ids)
        public
        view
        returns (uint256[] memory)
    {
        assert(false);
        return new uint256[](_accounts.length);
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
        assert(false);
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
        assert(false);
    }

    /**
     * @notice Burn Circles in demurrage units.
     * @param _id Circles identifier for which to burn the Circles.
     * @param _value Demurraged value of the Circles to burn.
     */
    function burn(uint256 _id, uint256 _value) public {
        assert(false);
    }

    /**
     * @notice Burn a batch of Circles in demurrage units.
     * @param _ids Batch of Circles identifiers for which to burn the Circles.
     * @param _values Batch of demurraged values of the Circles to burn.
     */
    function burnBatch(uint256[] memory _ids, uint256[] memory _values) public {
        assert(false);
    }

    /**
     * @notice Burn Circles in inflationary units.
     * @param _id Circles identifier for which to burn the Circles.
     * @param _value Value of the Circles to burn in inflationary units.
     */
    function inflationaryBurn(uint256 _id, uint256 _value) public {
        assert(false);
    }

    /**
     * @notice Burn a batch of Circles in inflationary units.
     * @param _ids Batch of Circles identifiers for which to burn the Circles.
     * @param _values Batch of values of the Circles to burn in inflationary units.
     */
    function inflationaryBurnBatch(uint256[] memory _ids, uint256[] memory _values) public {
        assert(false);
    }

    /**
     * @notice Calculate the issuance for a human's avatar in demurraged units.
     * @param _human Address of the human's avatar to calculate the issuance for.
     */
    // function calculateIssuance(address _human) public view returns (uint256) {
    //     uint256 inflationaryIssuance = _calculateInflationaryIssuance(_human);
    //     // todo: similarly, cache this daily factor upon transfer (keep balanceOf a view function)
    //     int128 demurrageFactor = Math64x64.pow(GAMMA_64x64, super.day(block.timestamp));
    //     uint256 demurragedIssuance = Math64x64.mulu(demurrageFactor, inflationaryIssuance);
    //     return demurragedIssuance;
    // }

    // function calculateIssuanceDisplay(address _human) public view returns (uint256) {
    //     uint256 exactDemurrageIssuance = Math64x64.mulu(_calculateExactIssuance(_human), EXA);
    //     return exactDemurrageIssuance;
    // }

    // Internal functions

    /**
     * @notice Claim issuance for a human's avatar and update the last mint time.
     * @param _human Address of the human's avatar to claim the issuance for.
     */
    function _claimIssuance(address _human) internal {
        //     // update the inflation factor for today if not already cached
        //     super.updateTodaysInflationFactor();
        //     uint256 issuance = _calculateInflationaryIssuance(_human);
        //     require(issuance > 0, "No issuance to claim.");
        //     // mint personal Circles to the human
        //     _mint(_human, super.toTokenId(_human), issuance, "");

        //     // update the last mint time
        //     mintTimes[_human].lastMintTime = uint96(block.timestamp);
    }

    // function _calculateInflationaryIssuance(address _human) internal view returns (uint256) {
    //     // convert the exact issuance to inflationary units
    //     (int128 iB,) = super.todaysInflationFactor();
    //     int128 exactIssuance64x64 = _calculateExactIssuance(_human);
    //     uint256 inflationaryIssuance = Math64x64.mulu(Math64x64.mul(iB, exactIssuance64x64), EXA);
    //     return inflationaryIssuance;
    // }

    /**
     * @notice Calculate the exact issuance as 64x64 for a human's avatar.
     * @param _human Address of the human's avatar to calculate the issuance for.
     */
    function _calculateExactIssuance(address _human) public view returns (int128) {
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
        uint256 dA = super.day(startMint);

        // day of current block, dB
        uint256 dB = super.day(block.timestamp);

        // the difference of days between dB and dA used for the table lookups
        uint256 n = dB - dA;

        // calculate the number of seconds in day A until `startMint`, and adjust for hours
        int128 k = Math64x64.fromUInt((startMint - (dA * 1 days + inflation_day_zero)) / 1 hours);

        // Calculate the number of seconds remaining in day B after current timestamp
        int128 l = Math64x64.fromUInt(((dB + 1) * 1 days + inflation_day_zero - block.timestamp) / 1 hours + 1);

        // calculate the overcounted (demurraged) k (in day A) and l (in day B) hours
        int128 overcount = Math64x64.add(Math64x64.mul(R[n], k), l);

        // calculate the issuance for the period by counting full days and subtracting the overcount
        // and apply todays inflation factor
        // for details see ./specifications/TCIP009-demurrage.md
        // int128 issuance64x64 = Math64x64.mul(iB, Math64x64.sub(T[n], overcount));

        int128 issuanceExact64x64 = Math64x64.sub(T[n], overcount);

        return issuanceExact64x64;
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
