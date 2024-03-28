# CHANGELOG
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# v0.3.1

- [PR ]
    - temporarilly rename "Circles" to "Rings" and "CRC" to "RING", so that pre-release deployments are easily recognizable from the later production deployment
- [PR 123] 
    - fix: `personalMint` should not revert if issuance is zero;
    - add `calculateIssuanceWithCheck` to know issuance without minting (while possibly updating v1 mint status);
    - add testing for simple migration and invitation flows
    - improve test for Circles issuance, add test for consecutive periods in personal mint

## v0.3.0 

### Chiado deployment
```
Deployment Date: 2024-03-25 19:53:22 (GMT)
Version: 0.3.0
Git Commit: 63cc025a80350a453f7fefc3eedbd39e43d52075
Deployer Address: 0x7619F26728Ced663E50E578EB6ff42430931564c
Deployer Nonce: 63

Deployed Contracts:
Hub: 0xda2776764BF01DC7f77f5b58df62221c89958A89
Migration: 0xad0aeD7d4fdB82f6Ed3ddd851A7a3456c979dF7C
NameRegistry: 0x088D6f062fF77653D86BCcd6027CEa4CB09d9ACD
ERC20Lift: 0xa5c7ADAE2fd3844f12D52266Cb7926f8649869Da
StandardTreasury: 0xe1dCE89512bE1AeDf94faAb7115A1Ba6AEff4201
BaseGroupMintPolicy: 0x738fFee24770d0DE1f912adf2B48b0194780E9AD
MastercopyDemurrageERC20: 0xB6B79BeEfd58cf33b298A456934554cf440354aD
MastercopyInflationaryERC20: 0xbb76CF35ec106c5c7a447246257dcfCB7244cA04
MastercopyStandardVault: 0x5Ea08c967C69255d82a4d26e36823a720E7D0317
```
- first functionally complete implementation of ERC1155 Circles implementation

## [Unreleased]

- Make the trust relationship binary (and deprecate the trust limit). Rather than storing a binary mapping, we opt to store a linked list of the trusted nodes. This facilitates iterating from the contract state.

- The default time behaviour for contract state is to update per block. The social graph is rich data structure other processes need to compute over. While adding edges to the graph is a monotonic operation, removing (untrusting) edges can cause concurrency problems with path solvers. We therefore want the (edge-removal) changes to the graph to happen at a predictable, slower pace than the token flow across the graph. 