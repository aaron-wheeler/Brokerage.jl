module Model

import Base: ==

# StructTypes is used by JSON3 to do all of our object serialization
using StructTypes

export Portfolio, User, LimitOrder, MarketOrder, CancelOrder

#=
Brokerage uses 'id' to distinguish between multiple portfolios
Brokerage uses 'userid' to connect a Client to a portfolio
Clients can use 'name' to connect a Trader/Agent to a portfolio
Brokerage uses a universally designated INTEGER ticker id for assets in 'holdings'
Brokerage stores unique Transaction IDs in 'pendingorders' & 'completedorders'
=#
mutable struct Portfolio
    id::Int64 # service-managed
    userid::Int64 # service-managed
    name::String # passed by client
    cash::Float64 # passed by client, TODO: make this BigInt
    timespicked::Int64 # service-managed
    # holdings::Vector{Int64} # TODO: avoid making this 64-bit
    holdings::Dict{Symbol, Float64} # TODO: make this {Int8, BigInt}
    # ticker::Vector{Int64}
    # shares::Vector{Float64}
    pendingorders::Vector{Int64} # service-managed
    completedorders::Vector{Int64} # service-managed
end

# default constructors for JSON3
==(x::Portfolio, y::Portfolio) = x.id == y.id
Portfolio() = Portfolio(0, 0, "", 0.0, 0, Dict(), Int[0], Int[0])
# Portfolio() = Portfolio(0, 0, "", 0.0, 0, Int[], Float64[], Int[0], Int[0])
Portfolio(name, cash, holdings) = Portfolio(0, 0, name, cash, 0, holdings, Int[0], Int[0])
# Portfolio(name, cash, ticker, shares) = Portfolio(0, 0, name, cash, 0, ticker, shares, Int[0], Int[0])
StructTypes.StructType(::Type{Portfolio}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{Portfolio}) = :id # for 'get' function in Mapper; different portfolio rows with the same id # refer to the same portfolio

mutable struct User
    id::Int64 # service-managed
    username::String
    password::String
end

==(x::User, y::User) = x.id == y.id
User() = User(0, "", "")
User(username::String, password::String) = User(0, username, password)
User(id::Int64, username::String) = User(id, username, "")
StructTypes.StructType(::Type{User}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{User}) = :id

# ======================================================================================== #

abstract type Order end

# TODO: Test whether these really need to be mutable. Fix if not. 

mutable struct LimitOrder <: Order
    ticker::Int8 # 8-bit -> up to 127 assets, change to 16-bit for 32767 assets
    order_id::Int64 # TODO: make this service-managed
    order_side::String
    limit_price::Float64
    limit_size::Float64
    acct_id::Int64 # same id as portfolio.id
end # TODO: create field for fill_mode

# default constructors for JSON3
==(x::LimitOrder, y::LimitOrder) = x.order_id == y.order_id
LimitOrder() = LimitOrder(0, 0, "", 0.0, 0.0, 0)
# LimitOrder(ticker, order_id, order_side, limit_price, limit_size, acct_id) = LimitOrder(ticker, order_id, order_side, limit_price, limit_size, acct_id)
StructTypes.StructType(::Type{LimitOrder}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{LimitOrder}) = :order_id

mutable struct MarketOrder <: Order
    ticker::Int8 # 8-bit -> up to 127 assets, change to 16-bit for 32767 assets
    order_id::Int64 # service-managed; Do we need this?**
    order_side::String
    fill_amount::Float64 # invest by shares or funds depending on `byfunds` field (default = by shares)
    acct_id::Int64 # same id as portfolio.id
    byfunds::Bool
end
# no fill_mode field; only `fill_mode=allornone` used for market orders

# default constructors for JSON3
==(x::MarketOrder, y::MarketOrder) = x.order_id == y.order_id
MarketOrder() = MarketOrder(0, 0, "", 0.0, 0, false)
# MarketOrder(ticker::Int8, order_id::Int64, order_side::String, mo_size::Float64, acct_id::Int64) = MarketOrder(ticker, order_id, order_side, mo_size, acct_id, 0.0)
# MarketOrder(ticker::Int8, order_id::Int64, order_side::String, acct_id::Int64, funds::Float64) = MarketOrder(ticker, order_id, order_side, 0.0, acct_id, funds)
MarketOrder(ticker, order_id, order_side, fill_amount, acct_id) = MarketOrder(ticker, order_id, order_side, fill_amount, acct_id, false)
# MarketOrder(ticker, order_id, order_side, fill_amount, acct_id, byfunds) = MarketOrder(ticker, order_id, order_side, fill_amount, acct_id, byfunds)
StructTypes.StructType(::Type{MarketOrder}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{MarketOrder}) = :order_id

mutable struct CancelOrder <: Order
    ticker::Int8 # 8-bit -> up to 127 assets, change to 16-bit for 32767 assets
    order_id::Int64 # same order_id of the LimitOrder being canceled
    order_side::String
    limit_price::Float64 # same limit_price of the LimitOrder being canceled
    acct_id::Int64 # same id as portfolio.id
end
# CancelOrder only applies to limit orders
# TODO (low-priority): Add functionality to VL_LimitOrderBook to support canceling unmatched market orders (in case of no liquidity event)
# **VL_LimitOrderBook.order_matching line 327 already has fn `cancel_unmatched_market_order!` but it's not exported

# default constructors for JSON3
==(x::CancelOrder, y::CancelOrder) = x.order_id == y.order_id
CancelOrder() = CancelOrder(0, 0, "", 0.0, 0)
# CancelOrder(ticker, order_id, order_side, limit_price, acct_id) = CancelOrder(ticker, order_id, order_side, limit_price, acct_id)
StructTypes.StructType(::Type{CancelOrder}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{CancelOrder}) = :order_id

end # module