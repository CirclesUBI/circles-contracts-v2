# Circles Protocol

## Introducing Circles Protocol v2

We're excited to be working on Circles Protocol v2, where we focus on making things better for everyone who uses and builds on Circles. Learning from our journey since Circles began, we've tackled the challenges we faced in the early days.

In Circles v2, we make it easier and more inviting for users and developers to engage with Circles. Our goal is to foster an ecosystem of products and experiences building on Circles. We've also been busy updating our technology, using the latest in cryptography to enhance performance, scalability, and to bring a new level of privacy to the Circles experience.

## Why build Circles ?

Our standard money system is based on debt, primarily from banks. Repaying this debt requires more than the initial amount due to interest, ensuring a consistent return of funds to these financial institutions. This system indirectly encourages anticipating future economic growth, which can increase our demand on the planet's resources.

In Circles UBI, we introduce "Time Circles" (TiC), a money system backed by the equal passage of time for all people. Every hour, each individual can seamlessly add one TiC to their account, unconditionally. To ensure TiC remains a meaningful measure of value, we implement a decay mechanism: tokens diminish in value over time. This equilibrium between token creation and decay ensures a stable balance for everyone, today and for future generations.

Understanding "Time Circles" also means recognizing what they are not. While this brief overview may not capture the full depth of the discussion, let's set a clear foundation from the outset.

Time Circles is not a panacea for all economic challenges, but it is essential to understand its intended purpose. TiC isn't a promise of a universal standard of living across diverse regions. Instead, it's a commitment that no person should be completely without financial means. Think of TC as a baseline currency available to all.

Time Circles encourages circular spending. Its true worth will be determined by the quality and range of goods and services available for TiC. While other currencies may prioritize store-of-value, TiC complements this financial landscape, emphasizing circulation and utility.

Lastly, two crucial parameters underpin the TiC system. The first parameter straightforwardly defines the unit: one token for every human, every hour. The second parameter establishes the decay rate of TiC. With a vision for sustainability across generations, our approach is retrospective: taking an optimistic human lifespan of 80 years as a benchmark, a token minted today should, after those 80 years, carry negligible value.

## Specifications

🐉 **warning**: here be dragons. This repository is under construction and neither functionally complete or externally reviewed. It is shared publicly to enable early discussion, but should not be considered ready for use.

For questions, contact maintainer: Ben <benjamin.bollen@gnosis.io>

## Setting up development environment

This Solidity project uses Foundry as a toolkit. If you don't have Foundry installed yet, see instructions [below](#foundry-as-toolkit)

### Using Foundry to build the contracts
1. First, you'll need to clone the repository to your local machine:
    ```bash
    git clone https://github.com/CirclesUBI/circles-contracts-v2
    cd circles-contracts-v2
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
#### Chiado
To deploy the contracts to the Chiado testnet, run `./chiadoDeploy.sh` and supply a private key and API keys in `.env` file in the root directory (copy `.env.example` and set private information):
```shell
./script/deployments/chiadoDeploy.sh
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
