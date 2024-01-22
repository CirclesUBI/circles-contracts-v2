# Graph Operator

## Abstract

The graph contract provides the core functionality of a single path transfer for any avatar to call to send their Circles.
To allow extended ability for future operators to do more complex graph operations, an avatar can enable a graph operator contract.

A graph operator can only touch those Circle nodes whos avatar has enabled the graph operator. Therefore the graph operator is required to work only on a subgraph.

A graph operator can be enabled, and then has unlimited allowance to move the enabled Circles around.
A graph operator MUST be an not-upgradable contract that implements the sufficient requirements to validate that
a request to send Circle tokens originates from the avatar to the desired recipient and the correct amount.

This is required so people can review the contract and rely on its correct functioning to enable it for them as a graph operator.

As an enabled graph operator, the address can access the `operateFlowMatrix` function, by providing a flow matrix and the associated netted flow to be verified and executed.

