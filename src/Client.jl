module Client
#=
    Client.jl: this module/layer defines client-side stuff

- The following functions mirror what is written in the Resource module
- The functions calls are routed to the appropriate method via Resource.jl
=#

using HTTP, JSON3, Base64, VLLimitOrderBook, AVLTrees, Dates

# `..` means use this layer as defined in the top level scope (as opposed to include())
using ..Model

#=
Server running on same host as client by default, listening on port 8080
Ref String - so that server address can be changed by client and accessed on different machine
E.g., Client.SERVER[] = "http://www.newaddress.com"
=#
const SERVER = Ref{String}("http://localhost:8080")

# ======================================================================================== #
#----- Account Functionality -----#

"""
    createUser(username::String, password::String) -> User

Create a new user with the given username and password.

# Arguments
- `username::String`: the username of the new user
- `password::String`: the password of the new user

# Returns
- `User`: the newly created user
"""
function createUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

"""
    loginUser(username::String, password::String) -> User

Login an existing user with the given username and password.

# Arguments
- `username::String`: the username of the user to be logged in
- `password::String`: the password of the user to be logged in

# Returns
- `User`: the logged in user
"""
function loginUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user/login"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

"""
    createPortfolio(name::String, cash::Float64, holdings::Dict{Int64, Int64}) -> Int64

Create a new portfolio with the given name, cash, and holdings.

# Arguments
- `name::String`: the name of the new portfolio
- `cash::Float64`: the amount of cash in the new portfolio
- `holdings::Dict{Int64, Int64}`: the holdings of the new portfolio, mapping asset IDs to
    the number of shares held. E.g., `Dict(1 => 10, 2 => 12)` means that the portfolio holds
    10 shares of asset 1 and 12 shares of asset 2.

# Returns
- `Int64`: the ID of the newly created portfolio
"""
function createPortfolio(name, cash, holdings)
    # JSON3 will serialize the named tuple into a json object for the Resource create portfolio function
    body = (; name, cash, holdings)
    resp = HTTP.post(string(SERVER[], "/portfolio"), [], JSON3.write(body))
    return JSON3.read(resp.body, Int64)
end

"""
    createSeveralPortfolios(num_users::Int64, name::String, min_cash::Float64,
                            max_cash::Float64, min_holdings::Int64, max_holdings::Int64)

Efficient method to create several portfolios. Individual portfolio cash balances and share
holdings are randomly drawn using the given maximum and minimum bounds.

# Arguments
- `num_users::Int64`: the number of portfolios to be created
- `name::String`: the base name of the new portfolios
- `min_cash::Float64`: the minimum amount of cash in each new portfolio
- `max_cash::Float64`: the maximum amount of cash in each new portfolio
- `min_holdings::Int64`: the minimum number of shares of each asset in each new portfolio
- `max_holdings::Int64`: the maximum number of shares of each asset in each new portfolio
"""
function createSeveralPortfolios(num_users, name, min_cash, max_cash, min_holdings, max_holdings)
    body = (; num_users, name, min_cash, max_cash, min_holdings, max_holdings) 
    resp = HTTP.post(string(SERVER[], "/several_portfolios"), [], JSON3.write(body))
    return
end

"""
    getHoldings(id::Int64) -> NamedTuple

Get the holdings of the portfolio with the given ID.

# Arguments
- `id::Int64`: the ID of the portfolio whose holdings are to be retrieved

# Returns
- `NamedTuple`: a named tuple mapping asset IDs to the number of shares held. E.g.,
    `NamedTuple(1 = 10, 2 = 12)` means that the portfolio holds 10 shares of asset 1 and 12
    shares of asset 2.
"""
function getHoldings(id)
    resp = HTTP.get(string(SERVER[], "/portfolio_holdings/$id"))
    return JSON3.read(resp.body, NamedTuple)
end

"""
    getCash(id::Int64) -> Float64

Get the cash balance of the portfolio with the given ID.

# Arguments
- `id::Int64`: the ID of the portfolio whose cash balance is to be retrieved

# Returns
- `Float64`: the cash balance of the portfolio
"""
function getCash(id)
    resp = HTTP.get(string(SERVER[], "/portfolio_cash/$id"))
    return JSON3.read(resp.body, Float64)
end

## TODO: implement updatePortfolio function
# function updatePortfolio(portfolio)
#     resp = HTTP.put(string(SERVER[], "/portfolio/$(portfolio.id)"), [], JSON3.write(portfolio))
#     return JSON3.read(resp.body, Portfolio)
# end

"""
    deletePortfolio(id::Int64)

Delete the portfolio with the given ID.

# Arguments
- `id::Int64`: the ID of the portfolio to be deleted
"""
function deletePortfolio(id)
    resp = HTTP.delete(string(SERVER[], "/portfolio/$id"))
    return
end

# ======================================================================================== #
#----- Order Functionality -----#

"""
    placeLimitOrder(ticker::Int, order_side::String, limit_price::Float64, limit_size::Int,
                        acct_id::Int)

Place a limit order for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset being traded
- `order_side::String`: the side of the order, either "BUY_ORDER" or "SELL_ORDER"
- `limit_price::Float64`: the price at which the order will be executed
- `limit_size::Int`: the number of shares to be traded
- `acct_id::Int`: the assigned ID of the account placing the order
"""
function placeLimitOrder(ticker, order_side, limit_price, limit_size, acct_id)
    body = (; ticker, order_side, limit_price, limit_size, acct_id)
    resp = HTTP.post(string(SERVER[], "/l_order"), [], JSON3.write(body))
    return # JSON3.read(resp.body, LimitOrder)
end

"""
    placeMarketOrder(ticker::Int, order_side::String, fill_amount::Int, acct_id::Int;
                        byfunds::Bool=false)

Place a market order for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset being traded
- `order_side::String`: the side of the order, either "BUY_ORDER" or "SELL_ORDER"
- `fill_amount::Int`: the number of shares to be traded
- `acct_id::Int`: the assigned ID of the account placing the order

# Keywords
- `byfunds::Bool=false`: if true, the `fill_amount` is interpreted as a dollar amount of
    funds to be spent on the order. If false, the `fill_amount` is interpreted as a number
    of shares to be traded.
"""
function placeMarketOrder(ticker, order_side, fill_amount, acct_id; byfunds = false)
    body = (; ticker, order_side, fill_amount, acct_id, byfunds)
    resp = HTTP.post(string(SERVER[], "/m_order"), [], JSON3.write(body))
    return # JSON3.read(resp.body, MarketOrder)
end

"""
    placeCancelOrder(ticker::Int, order_id::Int, order_side::String, limit_price::Float64,
                        acct_id::Int)
            
Place a cancel order for a given asset and given limit order.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset being traded
- `order_id::Int`: the assigned ID of the order to be cancelled
- `order_side::String`: the side of the order, either "BUY_ORDER" or "SELL_ORDER"
- `limit_price::Float64`: the limit price of the order to be cancelled
- `acct_id::Int`: the assigned ID of the account placing the order
"""
function placeCancelOrder(ticker, order_id, order_side, limit_price, acct_id)
    body = (; ticker, order_id, order_side, limit_price, acct_id)
    resp = HTTP.post(string(SERVER[], "/c_order"), [], JSON3.write(body))
    return # JSON3.read(resp.body, CancelOrder)
end

# ======================================================================================== #
#----- Order Book Functionality -----#

"""
    getMidPrice(ticker::Int) -> Float64

Get the mid price of the order book for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset whose order book is to be queried

# Returns
- `Float64`: the mid price of the order book (the average of the best bid and best ask
    prices)
"""
function getMidPrice(ticker)
    resp = HTTP.get(string(SERVER[], "/quote_mid_price/$ticker"))
    return JSON3.read(resp.body, Float64)
end

"""
    getBidAsk(ticker::Int) -> Tuple{Float64, Float64}

Get the best bid and ask prices in the order book for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset whose order book is to be queried

# Returns
- `Tuple{Float64, Float64}`: a tuple of the best bid and ask prices in the order book,
    where the first element is the best bid price and the second element is the best ask
"""
function getBidAsk(ticker)
    resp = HTTP.get(string(SERVER[], "/quote_top_book/$ticker"))
    return JSON3.read(resp.body, Tuple{Float64, Float64}) # could also skip Tuple arg and just return as JSON3 Array
end

"""
    getBookDepth(ticker::Int) -> Dict{Symbol, Dict{Symbol, Any}}

Get the order book depth for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset whose order book is to be queried

# Returns
- `Dict{Symbol, Dict{Symbol, Any}}`: a nested dictionary of prices, volumes, and order
    counts up to a depth of 5 price levels
"""
function getBookDepth(ticker) # nested dict of prices, volumes and order counts at a specified max_depth (default = 5)
    resp = HTTP.get(string(SERVER[], "/quote_depth/$ticker"))
    return JSON3.read(resp.body, Dict{Symbol, Dict{Symbol, Any}}) # could also skip Tuple arg and just return as JSON3 Array
end

"""
    getBidAskVolume(ticker::Int) -> Tuple{Int64, Int64}

Get the total bid and ask volume in the order book for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset whose order book is to be queried

# Returns
- `Tuple{Int64, Int64}`: a tuple of the total bid and ask volume in the order book, where
    the first element is the total bid volume and the second element is the total ask volume
"""
function getBidAskVolume(ticker)
    resp = HTTP.get(string(SERVER[], "/quote_book_volume/$ticker"))
    return JSON3.read(resp.body, Tuple{Int64, Int64}) # this Tuple type must match the one specified for order sizes in OMS layer
end

"""
    getBidAskOrders(ticker::Int) -> Tuple{Int32, Int32}

Get the total number of orders on each side of the order book for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset whose order book is to be queried

# Returns
- `Tuple{Int32, Int32}`: a tuple of the total number of orders on each side of the order
    book, where the first element is the total number of buy orders and the second element
    is the total number of sell orders
"""
function getBidAskOrders(ticker)
    resp = HTTP.get(string(SERVER[], "/quote_book_orders/$ticker"))
    return JSON3.read(resp.body, Tuple{Int32, Int32}) # Int32 as given by VL_LimitOrderBook
end

"""
    getPriceSeries(ticker::Int) -> Vector{Float64}

Get the price series for a given asset. The price series vector is maintained as a
CircularBuffer, where the most recent price is at the end of the vector. The length of the
vector is determined by the `PRICE_BUFFER_CAPACITY` constant in the OMS module.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset whose price series is to be queried

# Returns
- `Vector{Float64}`: a vector of the price series for the given asset
"""
function getPriceSeries(ticker)
    resp = HTTP.get(string(SERVER[], "/price_history/$ticker"))
    return JSON3.read(resp.body, Vector{Float64})
end

"""
    getMarketSchedule() -> Tuple{DateTime, DateTime}

Get the market open and close times.

# Returns
- `Tuple{DateTime, DateTime}`: a tuple of the market open and close times
"""
function getMarketSchedule()
    resp = HTTP.get(string(SERVER[], "/market_schedule"))
    return JSON3.read(resp.body, Tuple{DateTime, DateTime})
end

# ======================================================================================== #
#----- Market Maker Functionality -----#

"""
    provideLiquidity(ticker::Int, order_side::String, limit_price::Float64, limit_size::Int,
                        acct_id::Int; send_id::Bool=false) -> Int64 if send_id else nothing

Provide liquidity to the order book for a given asset. This method allows a market maker to
place a limit order on the order book without having a corresponding cash balance or share
holding. Each order is assigned a unique ID, which is returned by this method if the keyword
argument `send_id` is set to `true`.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset being traded
- `order_side::String`: the side of the order, either "BUY_ORDER" or "SELL_ORDER"
- `limit_price::Float64`: the price at which the order will be executed
- `limit_size::Int`: the number of shares to be traded
- `acct_id::Int`: the assigned ID of the account placing the order. This ID must be
    registered as a market maker account (i.e., it must be a number less than or equal to
    the value of the `MM_COUNTER` constant in the Mapper module).

# Keywords
- `send_id::Bool=false`: if true, the ID of the order is returned by this method. If false,
    nothing is returned.

# Returns
- `Int64`: the ID of the order if `send_id` is `true`
"""
function provideLiquidity(ticker, order_side, limit_price, limit_size, acct_id; send_id=false)
    body = (; ticker, order_side, limit_price, limit_size, acct_id, send_id)
    resp = HTTP.post(string(SERVER[], "/liquidity"), [], JSON3.write(body))
    if send_id == false
        return
    else
        return JSON3.read(resp.body, Int64)
    end
end

"""
    hedgeTrade(ticker::Int, order_side::String, fill_amount::Int, acct_id::Int)

Hedge a trade for a given asset. This method allows a market maker to place a market order
on the order book without having a corresponding cash balance or share holding.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset being traded
- `order_side::String`: the side of the order, either "BUY_ORDER" or "SELL_ORDER"
- `fill_amount::Int`: the number of shares to be traded
- `acct_id::Int`: the assigned ID of the account placing the order. This ID must be
    registered as a market maker account (i.e., it must be a number less than or equal to
    the value of the `MM_COUNTER` constant in the Mapper module).
"""
function hedgeTrade(ticker, order_side, fill_amount, acct_id)
    body = (; ticker, order_side, fill_amount, acct_id)
    resp = HTTP.post(string(SERVER[], "/hedge"), [], JSON3.write(body))
    return
end

"""
    getTradeVolume(ticker::Int) -> Int64

Get the total trading volume for a given asset.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset whose trading volume is to be queried

# Returns
- `Int64`: the total trading volume for the given asset
"""
function getTradeVolume(ticker) # returns scalar value of the current total trading volume for a ticker
    resp = HTTP.get(string(SERVER[], "/trade_volume/$ticker"))
    return JSON3.read(resp.body, Int64) # this type must match the one specified for order sizes in OMS layer
end

"""
    getActiveOrders(acct_id::Int, ticker::Int) -> AVLTree{Int64, Order{Int64, Float64, Int64, Int64}}

Get all open orders assigned to a given account for a given asset.

# Arguments
- `acct_id::Int`: the assigned ID of the account whose open orders are to be queried
- `ticker::Int`: the assigned ticker ID of the asset whose open orders are to be queried

# Returns
- `AVLTree{Int64, Order{Int64, Float64, Int64, Int64}}`: an AVL tree mapping order IDs to
    orders. The AVLTree is an account map where the keys are order IDs and the values are
    the corresponding orders (composed of Order Size::Int64, Price::Float64,
    Order IDs::Int64, Account IDs::Int64).
"""
function getActiveOrders(acct_id, ticker) # returns an account map of all open orders assigned to account `acct_id`
    resp = HTTP.get(string(SERVER[], "/active_orders/$acct_id/$ticker"))
    return JSON3.read(resp.body, AVLTree{Int64,Order{Int64, Float64, Int64, Int64}}) # The account map is implemented as a `Dict` containing `AVLTree`s.
end

"""
    getActiveSellOrders(acct_id::Int, ticker::Int) 
                                -> Vector{Tuple{Int64, Order{Int64, Float64, Int64, Int64}}}

Get all open sell orders assigned to a given account for a given asset.

# Arguments
- `acct_id::Int`: the assigned ID of the account whose open sell orders are to be queried
- `ticker::Int`: the assigned ticker ID of the asset whose open sell orders are to be
    queried

# Returns
- `Vector{Tuple{Int64, Order{Int64, Float64, Int64, Int64}}}`: a vector of tuples, where
    each tuple contains an order ID and the corresponding sell order (composed of Order
    Size::Int64, Price::Float64, Order IDs::Int64, Account IDs::Int64).
"""
function getActiveSellOrders(acct_id, ticker)
    resp = HTTP.get(string(SERVER[], "/active_sell_orders/$acct_id/$ticker"))
    return JSON3.read(resp.body, Vector{Tuple{Int64, Order{Int64, Float64, Int64, Int64}}})
end

"""
    getActiveBuyOrders(acct_id::Int, ticker::Int) 
                                -> Vector{Tuple{Int64, Order{Int64, Float64, Int64, Int64}}}

Get all open buy orders assigned to a given account for a given asset.

# Arguments
- `acct_id::Int`: the assigned ID of the account whose open buy orders are to be queried
- `ticker::Int`: the assigned ticker ID of the asset whose open buy orders are to be
    queried

# Returns
- `Vector{Tuple{Int64, Order{Int64, Float64, Int64, Int64}}}`: a vector of tuples, where
    each tuple contains an order ID and the corresponding buy order (composed of Order
    Size::Int64, Price::Float64, Order IDs::Int64, Account IDs::Int64).
"""
function getActiveBuyOrders(acct_id, ticker)
    resp = HTTP.get(string(SERVER[], "/active_buy_orders/$acct_id/$ticker"))
    return JSON3.read(resp.body, Vector{Tuple{Int64, Order{Int64, Float64, Int64, Int64}}})
end

"""
    cancelQuote(ticker::Int, order_id::Int, order_side::String, limit_price::Float64,
                    acct_id::Int)

Cancel a limit order for a given asset. Intended for use by market makers; the method does not
consolidate cash and share balances and is used to track market maker cancellation volume
over time.

# Arguments
- `ticker::Int`: the assigned ticker ID of the asset being traded
- `order_id::Int`: the assigned ID of the order to be cancelled
- `order_side::String`: the side of the order, either "BUY_ORDER" or "SELL_ORDER"
- `limit_price::Float64`: the limit price of the order to be cancelled
- `acct_id::Int`: the assigned ID of the account placing the order. This ID must be
    registered as a market maker account (i.e., it must be a number less than or equal to
    the value of the `MM_COUNTER` constant in the Mapper module).
"""
function cancelQuote(ticker, order_id, order_side, limit_price, acct_id)
    body = (; ticker, order_id, order_side, limit_price, acct_id)
    resp = HTTP.post(string(SERVER[], "/c_liquidity"), [], JSON3.write(body))
    return
end

end # module