# Global Allowance

## Simple specification

Global Allowance solves for the "ancillary extension" of the Circles protocol.

Circles should allow other contracts and protocols to easily operate on the Circle balances (personal and group) a person has. For many use-cases the known {ERC20-transferFrom} suffices by setting the allowance through approval.

However a person may have many balances across the graph, so rather than setting the approval for every node of the graph, we can extend the concept from the local ERC20 contracts to a global allowance that is valid for all ERC20 contracts across the graph.

Upon extending the concept, we must choose how to integrate the two values (local and global) of the allowance variable (per ERC20 Circles contract). There are two obvious paths: additive or overriding.

Overriding most respects the callers intent, but still leaves open the question: what is the variable that decides the override. A first proposal would be that a non-zero local allowance overrides any global allowance. However, this also has a sharp edge: once the local allowance is spent, the global allowance could take effect, which would violate most developer expectations.

To resolve this we propose to track the timestamp when an allowance, local or global is set, and the most recent value overrides the allowance. If both local and global allowance is set in the same block (resulting in the same timestamp), then the local allowance overrides the global allowance.