// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/migration/IHub.sol";

contract Token is ERC20 {
    uint256 public lastTouched; // the timestamp of the last ubi payout
    address public hub; // the address of the hub this token was deployed through
    address public immutable owner; // the safe that deployed this token
    uint256 public inflationOffset; // the amount of seconds until the next inflation step
    uint256 public currentIssuance; // issanceRate at the time this token was deployed
    bool private manuallyStopped; // true if this token has been stopped by it's owner

    /// @dev modifier allowing function to be only called through the hub
    modifier onlyHub() {
        require(msg.sender == hub);
        _;
    }

    /// @dev modifier allowing function to be only called by the token owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address _owner) ERC20("CirclesV1", "CRC") {
        require(_owner != address(0));
        owner = _owner;
        hub = msg.sender;
        lastTouched = time();
        inflationOffset = findInflationOffset();
        currentIssuance = IHubV1(hub).issuance();
        _mint(_owner, IHubV1(hub).signupBonus());
    }

    /// @notice helper function for block timestamp
    /// @return the block timestamp
    function time() public view returns (uint256) {
        return block.timestamp;
    }

    /// @notice helper function for the token symbol
    /// @dev all circles tokens should have the same symbol
    /// @return the token symbol    function name() external view returns (string memory);

    function symbol() public view override returns (string memory) {
        return IHubV1(hub).symbol();
    }

    /// @notice helper function for the token name
    /// @dev all circles tokens should have the same name
    /// @return the token name
    function name() public view override returns (string memory) {
        return IHubV1(hub).name();
    }

    /// @notice helper function for fetching the period length from the hub
    /// @return period length in seconds
    function period() public view returns (uint256) {
        return IHubV1(hub).period();
    }

    /// @notice helper function for fetching the number of periods from the hub
    /// @return the number of periods since the hub was deployed
    function periods() public view returns (uint256) {
        return IHubV1(hub).periods();
    }

    /// @notice helper function for fetching the timeout from the hub
    /// @return the number of seconds the token can go without being updated before it's deactivated
    function timeout() public view returns (uint256) {
        return IHubV1(hub).timeout();
    }

    /// @notice find the inflation step when ubi was last payed out
    /// @dev ie. if ubi was last payed out during the second inflation step, returns two
    /// @return the inflation step by count
    function periodsWhenLastTouched() public view returns (uint256) {
        return (lastTouched - hubDeployedAt()) / period();
    }

    /// @notice helper functio for getting the hub deployment time
    /// @return the timestamp the hub was deployed at
    function hubDeployedAt() public view returns (uint256) {
        return IHubV1(hub).deployedAt();
    }

    /// @notice Caution! manually deactivates or stops this token, no ubi will be payed out after this is called
    /// @dev intended for use in case of key loss, system failure, or migration to new contracts
    function stop() public onlyOwner {
        manuallyStopped = true;
    }

    /// @notice checks whether this token has been either stopped manually, or whether it has timed out
    /// @dev combines the manual stop variable with a dead man's switch
    /// @return false is the token is still paying out ubi, otherwise true
    function stopped() public view returns (bool) {
        if (manuallyStopped) return true;
        uint256 secondsSinceLastTouched = time() - lastTouched;
        if (secondsSinceLastTouched > timeout()) return true;
        return false;
    }

    /// @notice the amount of seconds until the ubi payout is next inflated
    /// @dev ubi is payed out continuously between inflation steps
    /// @return the amount of seconds until the next inflation step
    function findInflationOffset() public view returns (uint256) {
        // finds the timestamp of the next inflation step, and subtracts the current timestamp
        uint256 nextInflation = (period() * (periods() + 1)) + hubDeployedAt();
        return nextInflation - time();
    }

    /// @notice checks how much ubi this token holder is owed, but doesn't update their balance
    /// @dev is called in the update method to write the new balance to state, but also useful in wallets
    /// @return how much ubi this token holder is owed
    function look() public view returns (uint256) {
        // don't payout ubi if the token has been deactivated/stopped
        if (stopped()) return 0;
        uint256 payout = 0;
        uint256 clock = lastTouched;
        uint256 offset = inflationOffset;
        uint256 rate = currentIssuance;
        uint256 p = periodsWhenLastTouched();
        // this while loop gets executed only when we're rolling over an inflation step
        // in the course of a ubi payout aka while we have to pay out ubi for more time
        // than lastTouched + inflationOffset
        while (clock + offset <= time()) {
            // add the remaining offset time to the payout total at the current rate
            payout = payout + (offset * rate);
            // adjust clock to the timestamp of the next inflation step
            clock = clock + offset;
            // the offset is now the length of 1 period
            offset = period();
            // increment the period we are paying out for
            p = p + 1;
            // find the issuance rate as of the next period
            rate = IHubV1(hub).issuanceByStep(p);
        }
        // at this point, time() - clock should always be less than 1 period
        uint256 timeSinceLastPayout = time() - clock;
        payout = payout + (timeSinceLastPayout * rate);
        return payout;
    }

    /// @notice receive a ubi payout
    /// @dev this is the method to actually update storage with new token balance
    function update() public {
        uint256 gift = look();
        // does nothing if there's no ubi to be payed out
        if (gift > 0) {
            // update the state variables used to calculate ubi, then mint
            inflationOffset = findInflationOffset();
            lastTouched = time();
            currentIssuance = IHubV1(hub).issuance();
            _mint(owner, gift);
        }
    }

    /// @notice special method called by the hub to execute a transitive transaction
    /// @param from the address the tokens are being transfered from
    /// @param to the address the tokens are being transferred to
    /// @param amount the amount of tokens to transfer
    function hubTransfer(address from, address to, uint256 amount) public onlyHub returns (bool) {
        _transfer(from, to, amount);
        return true;
    }

    function transfer(address dst, uint256 wad) public override returns (bool) {
        // this code shouldn't be necessary, but when it's removed the gas estimation methods
        // in the gnosis safe no longer work, still true as of solidity 7.1
        return super.transfer(dst, wad);
    }
}
