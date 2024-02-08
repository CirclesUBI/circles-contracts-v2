// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Circles is ERC1155 {
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

    // Constructor

    constructor(string memory uri_) ERC1155(uri_) {}

    // External functions
}
