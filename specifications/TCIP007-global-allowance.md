# (Reflections on) Global Allowance -- MUST BE REWRITTEN

Every Circle node implements the ERC20 interface. As part of the ERC20 interface
allowance enables external contracts to interact with the token balance of owners.

In Circles under normal behaviour of the protocol an avatar accumulates balances
in the Circle nodes of avatars they have trusted. It therefore becomes cumbersome
to manually set an allowance for each Circle node that one might have a balance on.

A critical part of the Circles protocol pertains to the path transfer of Circles
over the flow graph induced by the trust graph.
The conservative implementation requires the avatar to initiate the path transfer,
but this limits how the protocol can interact with new methods that have been developed, in particular with an intent-based architecture.

In an intent-based architecture the owner can sign final constraints they request
to hold after the execution of a transaction, while leaving open the details of what transaction might achieve the requested end-state for them.

With the proposal of a global allowance we want to enable the Circles protocol
to be compatible with such extensions, whether an intent-based path solver network
for Circles directly, or compatibility with other external protocols.

## Specification

With `global allowance` the `Graph` contract holds an additional allowance
value for each (`owner`, `spender`) pair which then apply to all Circle node ERC20
contracts registered in this graph for the balance of said `owner`.

When trying to generalize the allowance across all Circle node contracts we need
to resolve the duplicated state, as there is an allowance kept globally and locally for each Circle node.

We propose that upon spending the allowance with `transferFrom` in a Circle node
the global an local allowance are additive. The spending should be continuous so a call will succeed if a sufficient combined allowance is present.
Thirdly the global allowance is depleted first, afterwards the local allowance is spent.

The global allowance should leave the local ERC20 behaviour of allowances intact.
Because we want to the spending to be continuous, the `allowance(owner, spender)`
call should return the summed global and local allowance for that contract.
However, we inevitably have slight breakages by introducing a dual state:
upon calling `approve(spender, value)` on the Circle node, the contract should
set the local allowance value. By calling `approve(spender, value)` on the graph
contract, it should set the global value of the allowance.

Allowance is often extended with `decreaseAllowance` and `increaseAllowance`
which should simply still act on the local allowance value. We do not recommend to
implement a global `decreaseAllowance` and `increaseAllowance` on the graph contract, but this self-evidently be opted for.

## Expected usage

We expect the global allowance to be used for people to opt-in to novel protocol
extensions such as the intent-architecture as explained. We therefore expect the default global allowance to be set to the maximum value of `uint256`, effectively infinity.

As desribed above, the obvious extension of the allowance to a global scope is
by duplicating the state value of a global and local allowance. However, upon
examining the possible implementations it is apparent the required logic requires
a higher branching complexity to spend across global and local allowance values.

We can therefore consider the global allowance to be a boolean value, rather than
an integer allowance amount. By separating the types, there is no longer
a duplication of state across the local and global contract state; the global
allowance now means an unlimited spending ability for the allowed protocol,
while enabled.

This reduces complexity of understanding the global allowance for consumers
of the interface. It resolves questions on the ambiguous behaviour of
`allowance()`.

Most importantly it actually matches the intended behaviour when setting the
(global) allowance to `max_uint256` for a trusted protocol contract.

We therefore propose instead this binary implementation for global allowance.

## Time scales for disabling a global allowance

Opting for the binary implementation of the global allowance, additionally
opens the opportunity to delay the disallowance of a protocol contract at the global level, with the same time delay as untrusting an avatar has.

We implemented such a time-delay to allow synchronization between the execution
of protocol contracts (in particular a solver network), and the state changes in
the contract state. For an integer global allowance such a time delay would be
difficult to sensibly construct.
