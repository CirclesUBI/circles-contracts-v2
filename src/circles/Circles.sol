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
     * @dev ERC1155 tokens MUST be 18 decimals. Used to calculate the issuance rate.
     */
    uint8 public constant DECIMALS = uint8(18);

    /**
     * @notice Issue one Circle per hour for each human.
     */
    uint256 public constant ISSUANCE_PERIOD = 1 hours;

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

    // Constructor

    constructor(string memory uri_) ERC1155(uri_) {}

    // External functions

    // Internal functions

    function _claimIssuance() internal {}

    function _calculateIssuance(address _human) internal returns (uint256) {
        MintTime storage mintTime = mintTimes[_human];
        require(
            mintTime.mintV1Status == address(0) || mintTime.mintV1Status == CIRCLES_STOPPED_V1,
            "Circles v1 contract cannot be active."
        );
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
}
