# Temporal discounting of tokens

## Introduction

We specify the outline and assumptions under which we can implement temporally discounted tokens.

## Objective

We want to have an accurate, effective and transparant method to issue one token per hour per human, unconditionally.

If we only mint tokens, the supply would increase linearly and the system would be useless.
Instead we want to design a system with a steady-state (ie. if no-one earns or spends tokens for a long time) in which every unique human has approximately the same balance. As such we will need to discount older tokens, to offset the minting of new tokens.

In some aspects, this is the inverse of a more conventional, inflationary system: here, balances remain constant (without sending or receiving amounts), but the amount of newly introduced tokens must increase over time to depreciate the already existing total supply. While this has been the conventional method to build money systems (in part because of technological constraints), it creates information asymmetry as it hides to people their stored value is in effect depreciating. This is of course worsened, if the newly printed tokens are issued by a central entity and not equally distributed.

To invert this relationship, we need to introduce a time-dependency on account balances, such that we can have a constant addition of new tokens into each account. This document outlines a specification to achieve such a system.

## Scope

We implement this system on a smart contract substrate and as such work with these induced requirements.
Specifically, it already is a strongly consistent state machine with an internal linearized time (block timestamps).

If we take a step back, we can identify four timescales over which the whole system needs to operate.
In this document we will be limited to only three of those timescales.
1. First we want people to be able to use (ie. **sign**) token transfers **under 100ms**.
2. Tokens should be able to flow (ie. **transfer solutions confirmed**) in the **order of seconds** (after signing).
3. In Circles tokens flow over a social graph, and this **graph is dynamic**: trust between people gets confirmed or revoked. These changes are represented as the addition or removal of edges over which tokens can flow. While adding edges is monotonous function and can be done without synchronisation, removing edges from this graph can create concurrency problems if it is not synchronised between processes. We therefore want (removal) changes to the social graph to happen slower than the flow of tokens over this graph, and introduce a delay in the **order of a minute** to effectuate edge removal from the graph.
4. The fourth timescale is the time resolution with which the tokens should be temporally discounted. It is important to note that this is not the rate of decay of the token discounting. Rather if we imagine the continuous function by which tokens should be discounted, we can chose how accurately we want to follow this analytical curve. The most accurate resolution would be one second (as block timestamps are expressed in seconds). However, both for people interacting with the tokens, as well as for other software components, it is constructive for token balances to be "known for some time", ie. not continuously updating. In the previous system, the inflation adjustment for minting is recalculated per year. Such a long period introduces edge cases though, and we  prefer a more accurate accounting. We have some freedom to choose here, as it is a balance between the smoothness of discounting tokens, versus seemingly jumps in balances. We propose an accuracy for the **time resolution for discounting** the balances of **one day**.

## System Overview


