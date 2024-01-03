# Brokerage.jl

<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://aaron-wheeler.github.io/Brokerage.jl/stable/) -->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://aaron-wheeler.github.io/Brokerage.jl/dev/)
<!-- [![Build Status](https://github.com/aaron-wheeler/Brokerage.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/aaron-wheeler/Brokerage.jl/actions/workflows/CI.yml?query=branch%3Amain) -->

This repository contains the source code for:

* [Introducing a financial simulation ecosystem in Julia | Aaron Wheeler | JuliaCon 2023](https://www.youtube.com/watch?v=C2Itnbwf9hg)
* [arXiv preprint] [Scalable Agent-Based Modeling for Complex Financial Market Simulations](https://arxiv.org/abs/2312.14903)

Related repositories include:

* [TradingAgents.jl](https://github.com/aaron-wheeler/TradingAgents.jl)

## Description

Brokerage.jl is a software package that works with [TradingAgents.jl](https://github.com/aaron-wheeler/TradingAgents.jl) to run agent-based simulations of financial markets. This package implements the core functionality of both the Brokerage and Artificial Stock Exchange, including order book hosting and matching, agent cash and share balance maintenance, and data storage and collection. In other words, Brokerage.jl acts as a trading platform for agents to interface with.

Brokerage.jl is implemented as a microservice-based application over REST API. This API enables agents to communicate across various machines, scale to large agent populations, and process decisions in parallel.

## Usage

### Installing Julia
This package uses the [Julia](https://julialang.org) programming language. You can find the installation instructions for Julia [here](https://julialang.org/downloads/).

### Installing Brokerage.jl
Clone the repository
```zsh
git clone https://github.com/aaron-wheeler/Brokerage.jl.git
```
External package dependencies (such as the matching engine package [VLLimitOrderBook.jl](https://github.com/aaron-wheeler/VLLimitOrderBook.jl)) can be installed from the [Julia REPL](https://docs.julialang.org/en/v1/stdlib/REPL/); start Julia and press the `]` key to enter [pkg mode](https://pkgdocs.julialang.org/v1/repl/) and the issue the command:
```
add https://github.com/aaron-wheeler/VLLimitOrderBook.jl.git
```
To test the installation, you can run the following command in the same location (pkg mode REPL):
```
test
``` 

### Example - Local Brokerage Server
An example of a simple locally hosted Brokerage server is provided below.
```julia
using Dates, Brokerage

# initialize database; to init with a new database -> "../test/new_db_name.sqlite" 
const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolios.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")
Mapper.MM_COUNTER[] = 30 # number of accounts reserved for market makers

# initialize LOB
OMS.NUM_ASSETS[] = 2 # number of assets
OMS.PRICE_BUFFER_CAPACITY[] = 100 # number of price points to store
OMS.MARKET_OPEN_T[] = Dates.now() + Dates.Minute(1) # market open time
OMS.MARKET_CLOSE_T[] = OMS.MARKET_OPEN_T[] + Dates.Minute(10) # market close time
OMS.init_LOB!(OMS.ob, OMS.LP_order_vol, OMS.LP_cancel_vol, OMS.trade_volume_t, OMS.price_buffer)

# initialize server
server = @async Brokerage.run(DBFILE, AUTHFILE)

# initialize user
Client.createUser("username", "password")
user = Client.loginUser("username", "password")

# initialize trading agents
portfolio_1 = Client.createPortfolio("Trader 1", 10500.0, Dict(1 => 10, 2 => 12))
portfolio_2 = Client.createPortfolio("Trader 2", 9000.0, Dict(1 => 15, 2 => 5))

# example trade (asset 1): market buy order (order_2) matches with limit sell order (order_1)
order_1 = Client.placeLimitOrder(1, "SELL_ORDER", 99.0, 7, portfolio_1)
order_2 = Client.placeMarketOrder(1, "BUY_ORDER", 5, portfolio_2)

# Trader 1 cancels the rest of unmatched limit order (order_1)
active_orders = Client.getActiveOrders(portfolio_1, 1)
order_id = first(active_orders)[1]
Client.placeCancelOrder(1, order_id, "SELL_ORDER", 99.0, portfolio_1)
```
The [main test script](https://github.com/aaron-wheeler/Brokerage.jl/blob/main/test/main_test.jl) provides more details about how agent state is maintained along with example usage of other functions that are available to the client. For a more exhaustive overview of the package's functionality, please refer to the [documentation](https://aaron-wheeler.github.io/Brokerage.jl/dev/).

### Example - Remote Brokerage Server
An example of a simple remotely hosted Brokerage server is provided below.
```julia
using Brokerage, Dates, Sockets

# initialize database and LOB(s)
const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolio.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")
Mapper.MM_COUNTER[] = 500 # number of accounts reserved for market makers
init_price = rand(85.0:115.0, 30) # specify initial price of 30 unique assets to be between $85 - $115
OMS.NUM_ASSETS[] = length(init_price) # number of assets
OMS.PRICE_BUFFER_CAPACITY[] = 100 # number of price points to store
OMS.MARKET_OPEN_T[] = Dates.now() + Dates.Hour(3) # market open time
OMS.MARKET_CLOSE_T[] = OMS.MARKET_OPEN_T[] + Dates.Hour(1) # market close time
OMS.init_LOB!(OMS.ob, init_price, OMS.LP_order_vol, OMS.LP_cancel_vol, OMS.trade_volume_t, OMS.price_buffer)

# initialize server
server = @async Brokerage.remote_run(DBFILE, AUTHFILE)
    
# show message to user
port_number = 8080
host_ip_address = Sockets.getipaddr()
@info "Server started. address: $(host_ip_address) port: $(port_number) at $(Dates.now(Dates.UTC))"
```
The host IP address and port number are then used to connect to the Brokerage server from either the same or a different machine. The following commands are used (from a new terminal with Julia started) to accomplish this:
```julia
using Dates, Brokerage

# connect to brokerage
host_ip_address = # FILL ME IN
port = # FILL ME IN
url = "http://$(host_ip_address):$(port)"
Client.SERVER[] = $url
Client.createUser("username", "password")
user = Client.loginUser("username", "password")

# retrieve market open/close times
market_open, market_close = Client.getMarketSchedule()

# TODO: initialize trading agents, fill in trading logic, etc. See TradingAgents.jl package for this. 
```
To get started with running agent-based simulations of financial markets, we recommend using the remote server to host the Brokerage/LOB(s) and using the agent behaviors defined in the [TradingAgents.jl](https://github.com/aaron-wheeler/TradingAgents.jl) package for generating market activity. 