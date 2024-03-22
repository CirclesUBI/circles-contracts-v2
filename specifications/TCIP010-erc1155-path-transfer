# ERC1155 applied to Circles path transfer

For now, a minimal description:
ERC1155 asks that the receiver of ERC1155 tokens actively is called upon receiving tokens with information about the transfer and optional bytes that must be passed from the sender to the receiver.

In Circles upon trusting the Circles of another person or of a group, you explicitly declare a 1:1 equivalence between your Circles and the trusted Circles.
The protocol exploits this to enable a path transfer over trust relations to transitively swap locally equivalent Circles, preserving balances for all intermediate actors.

As a result only a nett receiver at the end of a path transfer receives Circles, and only this receiver should be called with `{ERC1155-onReceived}` or `{ERC1155-onBatchReceived}`, combined with the intended data from the sender. As intermediate actors do not nett receive Circles along a path transfer, and Circles explicitly constructs for trusted Circles to be equivalent, internally mutating the Circles identifier of locally trusted Circles does not constitute "receiving Circles" and similarly `onReceived` should not be called on these intermediate actors.