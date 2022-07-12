module Client

using HTTP, JSON3, Base64
using ..Model

# server running on same host as client, listening on port 8080
# Ref String - we can easily change this later, Client.SERVER[] = "http://www.newaddress.com"
const SERVER = Ref{String}("http://localhost:8080")

# The following functions mirror what was written in the Resource module
# The functions calls are routed to the appropriate method via Resource.jl

# ======================================================================================== #
#----- Account Functionality -----#

function createUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

function loginUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user/login"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

function createPortfolio(name, cash, holdings)
    body = (; name, cash, holdings) # JSON3 will serialize this named tuple into a json object for the Resource create portfolio function 
    resp = HTTP.post(string(SERVER[], "/portfolio"), [], JSON3.write(body))
    return JSON3.read(resp.body, Portfolio)
end
# function createPortfolio(name, cash, ticker, shares)
#     body = (; name, cash, ticker, shares) # JSON3 will serialize this named tuple into a json object for the Resource create portfolio function 
#     resp = HTTP.post(string(SERVER[], "/portfolio"), [], JSON3.write(body))
#     return JSON3.read(resp.body, Portfolio)
# end

# function getPortfolio(id)
#     resp = HTTP.get(string(SERVER[], "/portfolio/$id"))
#     return JSON3.read(resp.body, Portfolio)
# end
function getHoldings(id)
    resp = HTTP.get(string(SERVER[], "/portfolio/$id"))
    return JSON3.read(resp.body, NamedTuple)
end

function updatePortfolio(portfolio)
    resp = HTTP.put(string(SERVER[], "/portfolio/$(portfolio.id)"), [], JSON3.write(portfolio))
    return JSON3.read(resp.body, Portfolio)
end

function deletePortfolio(id)
    resp = HTTP.delete(string(SERVER[], "/portfolio/$id"))
    return
end

function pickRandomPortfolio()
    resp = HTTP.get(string(SERVER[], "/"))
    return JSON3.read(resp.body, Portfolio)
end

# ======================================================================================== #
#----- Order Functionality -----#

function placeLimitOrder(ticker, order_id, order_side, limit_price, limit_size, acct_id)
    body = (; ticker, order_id, order_side, limit_price, limit_size, acct_id)
    resp = HTTP.post(string(SERVER[], "/order"), [], JSON3.write(body))
    return JSON3.read(resp.body, LimitOrder)
end

function placeMarketOrder(ticker, order_id, order_side, fill_amount, acct_id; byfunds = false)
    body = (; ticker, order_id, order_side, fill_amount, acct_id, byfunds)
    resp = HTTP.post(string(SERVER[], "/m_order"), [], JSON3.write(body))
    return JSON3.read(resp.body, MarketOrder)
end

function placeCancelOrder(ticker, order_id, order_side, limit_price, acct_id)
    body = (; ticker, order_id, order_side, limit_price, acct_id)
    resp = HTTP.post(string(SERVER[], "/c_order"), [], JSON3.write(body))
    return JSON3.read(resp.body, CancelOrder)
end

# ======================================================================================== #
#----- Quote Functionality -----#

function getBidAsk(ticker) # returns tuple of best bid and ask prices in the order book
    resp = HTTP.get(string(SERVER[], "/quote_top_book/$ticker"))
    return JSON3.read(resp.body, Tuple{Float64, Float64}) # could also skip Tuple arg and just return as JSON3 Array
end

function getBookDepth(ticker) # nested dict of prices, volumes and order counts at a specified max_depth (default = 5)
    resp = HTTP.get(string(SERVER[], "/quote_depth/$ticker"))
    return JSON3.read(resp.body, Dict{Symbol, Dict{Symbol, Any}}) # could also skip Tuple arg and just return as JSON3 Array
end

function getBidAskVolume(ticker) # returns tuple of total bid and ask volume from order book
    resp = HTTP.get(string(SERVER[], "/quote_book_volume/$ticker"))
    return JSON3.read(resp.body, Tuple{Int64, Int64}) # this Tuple type must match the one specified for order sizes in OMS layer
end

function getBidAskOrders(ticker) # returns tuple of total number of orders on each side of order book
    resp = HTTP.get(string(SERVER[], "/quote_book_orders/$ticker"))
    return JSON3.read(resp.body, Tuple{Int32, Int32}) # Int32 as given by VL_LimitOrderBook
end

end # module