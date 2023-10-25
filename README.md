# Brokerage

<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://aaron-wheeler.github.io/Brokerage.jl/stable/) -->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://aaron-wheeler.github.io/Brokerage.jl/dev/)
<!-- [![Build Status](https://github.com/aaron-wheeler/Brokerage.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/aaron-wheeler/Brokerage.jl/actions/workflows/CI.yml?query=branch%3Amain) -->

This repository contains the source code for:

* [Introducing a financial simulation ecosystem in Julia | Aaron Wheeler | JuliaCon 2023](https://www.youtube.com/watch?v=C2Itnbwf9hg)
* Preprint (forthcoming)

Related repositories include:

* [TradingAgents.jl](https://github.com/aaron-wheeler/TradingAgents.jl)

## Description

Brokerage.jl is a software package that works with [TradingAgents.jl](https://github.com/aaron-wheeler/TradingAgents.jl) to run agent-based simulations of financial markets. This package implements the core functionality of both the Brokerage and Artificial Stock Exchange, including order book hosting and matching, agent cash and share balance maintenance, and data storage and collection. In other words, Brokerage.jl acts as a trading platform for agents to interface with.

Brokerage.jl is implemented as a microservice-based application over REST API. This API enables agents to communicate across various machines, scale to large agent populations, and process decisions in parallel.

## Installation

### Installing Julia
This package uses the [Julia](https://julialang.org) programming language. You can find the installation instructions for Julia [here](https://julialang.org/downloads/).

## Usage
Clone the repository
```sh
git clone https://github.com/aaron-wheeler/Brokerage.jl.git
```
External package dependencies can be installed from the [Julia REPL](https://docs.julialang.org/en/v1/stdlib/REPL/), press the `]` key to enter [pkg mode](https://pkgdocs.julialang.org/v1/repl/) and the issue the command:
```
add https://github.com/aaron-wheeler/VLLimitOrderBook.jl.git
```
To test the installation, you can run the following command in the same location (pkg mode REPL):
```
test
``` 

<!-- ## Example

TODO -->