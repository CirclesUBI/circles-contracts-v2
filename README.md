# Time Circles

Our standard money system is based on debt, primarily from banks. Repaying this debt requires more than the initial amount due to interest, ensuring a consistent return of funds to these financial institutions. This system indirectly encourages anticipating future economic growth, which can increase our demand on the planet's resources.

In Circles UBI, we introduce "Time Circles" (TC), a money system backed by the equal passage of time for all people. Every hour, each individual can seamlessly add one TC to their account, unconditionally. To ensure TC remains a meaningful measure of value, we implement a decay mechanism: tokens diminish in value over time. This equilibrium between token creation and decay ensures a stable balance for everyone, today and for future generations.

Understanding "Time Circles" also means recognizing what they are not. While this brief overview may not capture the full depth of the discussion, let's set a clear foundation from the outset.

Time Circles is not a panacea for all economic challenges, but it is essential to understand its intended purpose. TC isn't a promise of a universal standard of living across diverse regions. Instead, it's a commitment that no person should be completely without financial means. Think of TC as a baseline currency available to all.

Time Circles encourages circular spending. Its true worth will be determined by the quality and range of goods and services available for TC. While other currencies may prioritize store-of-value, TC complements this financial landscape, emphasizing circulation and utility.

Lastly, two crucial parameters underpin the TC system. The first parameter straightforwardly defines the unit: one token for every human, every hour. The second parameter establishes the decay rate of TC. With a vision for sustainability across generations, our approach is retrospective: taking an optimistic human lifespan of 80 years as a benchmark, a token minted today should, after those 80 years, carry negligible value.

## Specifications


## Setting up development environment

This Solidity project uses Foundry as a toolkit. If you don't have Foundry installed yet, see instructions [below](#foundry-as-toolkit)

### Using Foundry to build the contracts
1. First, you'll need to clone the repository to your local machine:
    ```bash
    git clone https://github.com/CirclesUBI/[DECIDE_ON_REPO_NAME]
    cd [DECIDE_ON_REPO_NAME]
    ```

### Compiling the contracts
1. To compile the contracts, use the following command:
    ```bash
    forge build
    ```
    Upon successful compilation, you'll find the generated artifacts (like ABI and bytecode) in the specified output directory, by default  `out/`.

2. To format the code, you can run:
    ```bash
    forge fmt
    ```
    or only check the correct formatting without changing the code:
    ```bash
    forge fmt --check
    ```

### Testing the contracts
1. To test the contracts, use the following command:
    ```bash
    forge test
    ```
    or to report on gas usage:
    ```bash
    forge test --gas-report
    ```
2. To create a snapshot file to disk of each test's gas usage, use:
    ```bash
    forge snapshot
    ```

### Deploying the contracts
1. [todo] To run a local development node, use the `anvil` command in a separate terminal:
    ```bash
    anvil
    ```

2. [todo] Run a local network node:
    ```bash
    forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
    ```
3. To access RPC calls from CLI, see:
    ```bash
    cast help
    ```

## Foundry as toolkit

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

You can find the installation guide for Foundry in their [book.getfoundry.sh - Getting started](https://book.getfoundry.sh/getting-started/installation)

Here we re-iterate the most important steps to get you started.

1. You can install precompiled binaries with their toolchain installer:
    ```bash
    curl -L https://foundry.paradigm.xyz | bash
    ```
    and follow the instructions in the terminal.
    To instead build from source, see their getting started guide.
