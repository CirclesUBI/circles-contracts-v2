# Tests for Circles contracts

## User stories

### TimeCircle.sol

The graph contract should be able to:

- [x] Set up the Time Circle contract with a valid avatar address and verify that the `graph` and `avatar` state variables are set correctly.
- [x] ~~Ensure that attempting to set up the Time Circle contract with a zero address for the avatar fails.~~
- [x] Verify that the `setup` function cannot be called more than once (i.e., the contract can only be set up once).
- [ ] Perform a `pathTransfer` and verify that tokens are correctly transferred between addresses when initiated by the graph.
- [ ] Verify that `pathTransfer` fails when called by an address other than the graph.

A person (or another contract) should be able to:

- [ ] Claim issuance tokens if the conditions are met (like waiting for at least one hour between claims) and validate that the correct amount of tokens is issued.
- [ ] Ensure that claiming issuance fails when the allocated time between claims has not passed.
- [ ] Stop the Time Circle by the avatar and check that the `stopped` state variable is set to true.
- [ ] Confirm that once stopped, the Time Circle cannot perform certain actions (like `migrate` or `claimIssuance`).
- [ ] Calculate issuance through `calculateIssuance` and ensure it returns the correct outstanding balance.
- [ ] Migrate tokens to the owner and verify the correct amount is minted, provided the Circle is not stopped.
- [ ] Ensure that the `migrate` function fails when the Circle is stopped.
- [ ] Burn a specified amount of tokens and verify the correct amount is burned from the sender's balance.
- [ ] Validate that the internal logic for calculating issuance (`_calculateIssuance`) aligns with expected outcomes based on different scenarios of allocations, timestamps, and discount windows. (see below)

#### Function _calculateIssuance()

- [ ] Allocation Tests:
    - [ ] Verify that issuing tokens with an allocation of exactly 0 results in zero available issuance.
    - [ ] Confirm that issuing tokens with an allocation of exactly 1 computes the correct available issuance.
    - [ ] Test that issuing tokens with a fractional allocation between 0 and 1 calculates the correct available issuance.
    - [ ] Ensure that the function reverts if the allocation is less than 0 or greater than 1.

- [ ] Earliest Timestamp Validity:
    - [ ] Check that the function returns zero available issuance if the earliest timestamp is set in the future.
    - [ ] Validate correct issuance calculation when the earliest timestamp is in the past.
    - [ ] Ensure correct behavior when the earliest timestamp is exactly equal to the current time.

- [ ] Issuance Start Calculation:
    - [ ] Test the function with earliestTimestamp greater than lastIssued.
    - [ ] Test the function with earliestTimestamp less than lastIssued.
    - [ ] Test the function with earliestTimestamp equal to lastIssued.
    - [ ] Test the function just before and just after the maximum claim duration ends.

- [ ] Duration Claimable and Issuance Period:
    - [ ] Verify correct issuance when the claim duration is exactly two weeks.
    - [ ] Verify correct issuance of maximally two weeks when the last issuance is longer ago than two weeks.
    - [ ] Test for correct issuance when the claim duration is less than two weeks.
    - [ ] Confirm zero issuance when no time has passed since the last issuance.

- [ ] Full Balance Without Discounting:
    - [ ] Test for a non-zero full balance calculation within a single discount window.
    - [ ] Ensure zero available issuance when the full balance without discounting is zero.

- [ ] Discount Window Calculations:
    - [ ] Confirm correct issuance when no discount windows have passed.
    - [ ] Test for correct issuance calculation over multiple discount windows.

- [ ] Loop Through Discount Windows:
    - [ ] Validate issuance calculations through a single iteration of the discount window loop.
    - [ ] Validate issuance calculations through multiple iterations of the discount window loop.

- [ ] Boundary Conditions:
    - [ ] Test the function just before a discount window changes.
    - [ ] Test the function just after a discount window changes.

- [ ] Exceptional Scenarios:
    - [ ] Ensure the function reverts in scenarios like invalid allocation or inappropriate setting of the earliest timestamp.

### TemporalDiscount.sol

A person should be able to: