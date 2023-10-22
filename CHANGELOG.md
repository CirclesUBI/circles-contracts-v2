# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

- Make the trust relationship binary (and deprecate the trust limit). Rather than storing a binary mapping, we opt to store a linked list of the trusted nodes. This facilitates iterating from the contract state.

- The default time behaviour for contract state is to update per block. The social graph is rich data structure other processes need to compute over. While adding edges to the graph is a monotonic operation, removing (untrusting) edges can cause concurrency problems with path solvers. We therefore want the (edge-removal) changes to the graph to happen at a predictable, slower pace than the token flow across the graph. 