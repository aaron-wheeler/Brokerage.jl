module Service
# perform the services defined in the Resource layer and validate inputs

using Dates, ExpiringCaches
using ..Model, ..Mapper, ..Auth, ..OMS
# using ..Model, ..NormalizedMapper, ..Auth

# ======================================================================================== #
#----- Account Services -----#

function createPortfolio(obj)
    @assert haskey(obj, :name) && !isempty(obj.name)
    @assert haskey(obj, :holdings) && !isempty(obj.holdings)
    # @assert haskey(obj, :ticker) && !isempty(obj.ticker)
    # @assert haskey(obj, :shares) && !isempty(obj.shares)
    @assert haskey(obj, :cash) && 1.0 < obj.cash < 1000000.0
    portfolio = Portfolio(obj.name, obj.cash, obj.holdings)
    # portfolio = Portfolio(obj.name, obj.cash, obj.ticker, obj.shares)
    Mapper.create!(portfolio)
    # NormalizedMapper.create!(portfolio)
    return portfolio
end

# @cacheable Dates.Hour(1) function getPortfolio(id::Int64)::Portfolio
#     Mapper.get(id)
#     # NormalizedMapper.get(id)
# end
function getHoldings(id::Int64)
    holdings = Mapper.getHoldings(id)
    return holdings
end

# consistent with model struct, not letting client define their own id, we manage these as a service
# function updatePortfolio(id, updated)
#     portfolio = Mapper.get(id)
#     # portfolio = NormalizedMapper.get(id)
#     portfolio.name = updated.name
#     portfolio.cash = updated.cash
#     portfolio.holdings = updated.holdings
#     Mapper.update(portfolio)
#     # NormalizedMapper.update(portfolio)
#     delete!(ExpiringCaches.getcache(getPortfolio), (id,))
#     return portfolio
# end

function deletePortfolio(id)
    Mapper.delete(id)
    # NormalizedMapper.delete(id)
    delete!(ExpiringCaches.getcache(getPortfolio), (id,))
    return
end

# function pickRandomPortfolio()
#     portfolios = Mapper.getAllPortfolios()
#     # portfolios = NormalizedMapper.getAllPortfolios()
#     leastTimesPicked = minimum(x->x.timespicked, portfolios)
#     leastPickedPortfolio = filter(x->x.timespicked == leastTimesPicked, portfolios)
#     pickedPortfolio = rand(leastPickedPortfolio)
#     pickedPortfolio.timespicked += 1
#     Mapper.update(pickedPortfolio)
#     # NormalizedMapper.update(pickedPortfolio)
#     delete!(ExpiringCaches.getcache(getPortfolio), (pickedPortfolio.id,))
#     @info "picked portfolio = $(pickedPortfolio.name) on thread = $(Threads.threadid())"
#     return pickedPortfolio
# end

# creates User struct defined in Model.jl
function createUser(user)
    @assert haskey(user, :username) && !isempty(user.username)
    @assert haskey(user, :password) && !isempty(user.password)
    user = User(user.username, user.password)
    Mapper.create!(user)
    # NormalizedMapper.create!(user)
    return user
end

# done this way so that we can persist user
function loginUser(user)
    persistedUser = Mapper.get(user)
    # persistedUser = NormalizedMapper.get(user)
    if persistedUser.password == user.password
        persistedUser.password = ""
        return persistedUser
    else
        println("persistedUser Login Error: User not recognized")
        throw(Auth.Unauthenticated())
    end
end

# ======================================================================================== #
#----- Order Services -----#

# TODO: make a @cacheable generalized function for creating orders, which is then called by placeOrder fns and deleted

struct InsufficientFunds <: Exception end
struct InsufficientShares <: Exception end

function placeLimitOrder(obj)
    @assert haskey(obj, :ticker) && !isempty(obj.ticker)
    @assert haskey(obj, :order_id) && !isempty(obj.order_id) # TODO: make this service-managed
    @assert haskey(obj, :order_side) && !isempty(obj.order_side)
    @assert haskey(obj, :limit_price) && !isempty(obj.limit_price)
    @assert haskey(obj, :limit_size) && !isempty(obj.limit_size)
    @assert haskey(obj, :acct_id) && !isempty(obj.acct_id)

    if obj.order_side == "BUY_ORDER"
        # check if sufficient funds available
        portfolio = Mapper.get(obj.acct_id) # TODO: make Mapper fn that just grabs Portfolio cash
        if portfolio.cash ≥ obj.limit_price * obj.limit_size
            # create and send order to OMS layer for fulfillment
            # TODO: create and return unique obj.order_id = transaction_id
            order = LimitOrder(obj.ticker, obj.order_id, obj.order_side, obj.limit_price, obj.limit_size, obj.acct_id)
            processTradeBid(order) # TODO: integrate @asynch functionality
            return order # return order confirmation
        else
            throw(InsufficientFunds())            
        end
    else # if obj.order_side == "SELL_ORDER"
        # check if sufficient shares available
        holdings = Mapper.getHoldings(obj.acct_id) # TODO: make Mapper fn that just grabs Portfolio holdings
        # TODO: Implement short-selling functionality
        ticker = obj.ticker
        shares_owned = get(holdings, Symbol("$ticker"), 0.0) 
        if shares_owned ≥ obj.limit_size
            # create and send order to OMS layer for fulfillment
            # TODO: create and return unique obj.order_id = transaction_id
            order = LimitOrder(obj.ticker, obj.order_id, obj.order_side, obj.limit_price, obj.limit_size, obj.acct_id)
            processTradeAsk(order) # TODO: integrate @asynch functionality
            return order # return order confirmation
        else
            throw(InsufficientShares())            
        end
    end
end

function placeMarketOrder(obj)
    @assert haskey(obj, :ticker) && !isempty(obj.ticker)
    @assert haskey(obj, :order_id) && !isempty(obj.order_id) # TODO: make this service-managed
    @assert haskey(obj, :order_side) && !isempty(obj.order_side)
    @assert haskey(obj, :fill_amount) && !isempty(obj.fill_amount)
    @assert haskey(obj, :acct_id) && !isempty(obj.acct_id)

    if obj.byfunds == false
        # administer market order by shares
        if obj.order_side == "BUY_ORDER"
            # check if sufficient funds available
            portfolio = Mapper.get(obj.acct_id) # TODO: make Mapper fn that just grabs Portfolio cash
            best_ask = (getBidAsk(obj.ticker))[2]
            if portfolio.cash ≥ best_ask * obj.fill_amount # TODO: Test the functionality here for robustness, asynch & liquidity could break this
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id)
                processTradeBuy(order) # TODO: integrate @asynch functionality
                return order # return order confirmation
            else
                throw(InsufficientFunds())            
            end
        else # if obj.order_side == "SELL_ORDER"
            # check if sufficient shares available
            holdings = Mapper.getHoldings(obj.acct_id) # TODO: make Mapper fn that just grabs Portfolio holdings
            # TODO: Implement short-selling functionality
            ticker = obj.ticker
            shares_owned = get(holdings, Symbol("$ticker"), 0.0)
            if shares_owned > 0.0
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id)
                processTradeSell(order) # TODO: integrate @asynch functionality
                return order # return order confirmation
            else
                throw(InsufficientShares())            
            end
        end
    else
        # administer market order by funds
        if obj.order_side == "BUY_ORDER"
            # check if sufficient funds available
            portfolio = Mapper.get(obj.acct_id) # TODO: make Mapper fn that just grabs Portfolio cash
            if portfolio.cash ≥ obj.fill_amount
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id, obj.byfunds)
                processTradeBuy(order) # TODO: integrate @asynch functionality
                return order # return order confirmation
            else
                throw(InsufficientFunds())            
            end
        else # if obj.order_side == "SELL_ORDER"
            # check if sufficient shares available
            holdings = Mapper.getHoldings(obj.acct_id) # TODO: make Mapper fn that just grabs Portfolio holdings
            # TODO: Implement short-selling functionality
            ticker = obj.ticker
            best_ask = (getBidAsk(obj.ticker))[2]
            shares_owned = get(holdings, Symbol("$ticker"), 0.0)
            if shares_owned * best_ask > obj.fill_amount # TODO: Test the functionality here for robustness, asynch & liquidity could break this
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id, obj.byfunds)
                processTradeSell(order) # TODO: integrate @asynch functionality
                return order # return order confirmation
            else
                throw(InsufficientShares())            
            end
        end
    end
end

function placeCancelOrder(obj)
    @assert haskey(obj, :ticker) && !isempty(obj.ticker)
    @assert haskey(obj, :order_id) && !isempty(obj.order_id) # TODO: Check if exists in LOB and portfolio.id -> pendingorders
    @assert haskey(obj, :order_side) && !isempty(obj.order_side)
    @assert haskey(obj, :limit_price) && !isempty(obj.limit_price)
    @assert haskey(obj, :acct_id) && !isempty(obj.acct_id)
  
    order = CancelOrder(obj.ticker, obj.order_id, obj.order_side, obj.limit_price, obj.acct_id)
    # send order to OMS layer for fulfillment
    cancelTrade(order) # TODO: integrate @asynch functionality (?)
    return order  
end

# ======================================================================================== #
#----- Quote Services -----#

function getBidAsk(ticker)
    top_book = OMS.queryBidAsk(ticker)
    return top_book
end

function getBookDepth(ticker)
    depth = OMS.queryBookDepth(ticker)
    return depth
end

function getBidAskVolume(ticker)
    book_volume = OMS.queryBidAskVolume(ticker)
    return book_volume
end

function getBidAskOrders(ticker)
    n_orders_book = OMS.queryBidAskOrders(ticker)
    return n_orders_book
end

# ======================================================================================== #
#----- Trade Services -----#

function processTradeBid(order::LimitOrder)
    trade = OMS.processLimitOrderPurchase(order)
    @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    # TODO: incorporate complete trade functionality below
    # if trade[1] == nothing
    #     @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    #     # TODO: update portfolio accordingly           
    # end

    # return
end

function processTradeAsk(order::LimitOrder)
    trade = OMS.processLimitOrderSale(order)
    @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    # TODO: incorporate complete trade functionality below
    # if trade[1] == nothing
    #     @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    #     # TODO: update portfolio accordingly           
    # end

    # return
end

function processTradeBuy(order::MarketOrder)
    trade = OMS.processMarketOrderPurchase(order)
    @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    # TODO: incorporate complete trade functionality below
    # if trade[1] == nothing
    #     @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    #     # TODO: update portfolio accordingly           
    # end

    # return
end

function processTradeSell(order::MarketOrder)
    trade = OMS.processMarketOrderSale(order)
    @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    # TODO: incorporate complete trade functionality below
    # if trade[1] == nothing
    #     @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
    #     # TODO: update portfolio accordingly           
    # end

    # return true ?
end

function cancelTrade(order::CancelOrder)
    # navigate order to correct location
    if order.order_side == "SELL_ORDER"
        canceled_trade = OMS.cancelLimitOrderSale(order)
        @info "Trade canceled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
        # TODO: incorporate complete trade functionality below
        # if trade[1] == nothing
        #     @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
        #     # TODO: update portfolio accordingly           
        # end
    elseif order.order_side == "BUY_ORDER"
        canceled_trade = OMS.cancelLimitOrderPurchase(order)
        @info "Trade canceled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
        # TODO: incorporate complete trade functionality below
        # if trade[1] == nothing
        #     @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
        #     # TODO: update portfolio accordingly           
        # end
    end
    # return true ?
end

# TODO: Other info messages (examples below)

# "Update (timestamp): Your order to sell 100 shares of NOK has been filled at an average price of $4.01 per share. Your order is complete."

# "We've received your order to open 1 MVIS Call Credit Spread at a minimum of $0.40 per unit. If this order isn't filled by the end of market hours today (4pm ET), it'll be canceled."
# "Your order to open 1 MVIS Call Credit Spread wasn't filled today, and has been automatically canceled."

# "Your order to sell to close 1 contract of T $29.50 Call 4/1 has been filled for an average price of $94.00 per contract. Your order is complete."

# "Update: Because you owned 0.526674 shares of NVDA on 6/8, you've received a dividend payment of $0.02."

end # module