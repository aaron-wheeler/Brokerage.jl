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
    @assert haskey(obj, :cash) && 1.0 < obj.cash
    portfolio = Portfolio(obj.name, obj.cash, obj.holdings)
    # portfolio = Portfolio(obj.name, obj.cash, obj.ticker, obj.shares)
    Mapper.create!(portfolio)
    # NormalizedMapper.create!(portfolio)
    # return portfolio
    return portfolio.id
end

# @cacheable Dates.Hour(1) function getPortfolio(id::Int64)::Portfolio
#     Mapper.get(id)
#     # NormalizedMapper.get(id)
# end
function getHoldings(id::Int64)
    holdings = Mapper.getHoldings(id)
    return holdings
end

function getCash(id::Int64)
    cash = Mapper.getCash(id)
    return cash
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
        throw(Auth.Unauthenticated("persistedUser login not recognized"))
    end
end

# ======================================================================================== #
#----- Order Services -----#

struct InsufficientFunds <: Exception end
struct InsufficientShares <: Exception end

function placeLimitOrder(obj)
    @assert haskey(obj, :ticker) && !isempty(obj.ticker)
    @assert haskey(obj, :order_id) && !isempty(obj.order_id) # TODO: make this service-managed
    @assert haskey(obj, :order_side) && !isempty(obj.order_side)
    @assert haskey(obj, :limit_price) && obj.limit_price > zero(obj.limit_price) 
    @assert haskey(obj, :limit_size) && obj.limit_size > zero(obj.limit_size) 
    @assert haskey(obj, :acct_id) && !isempty(obj.acct_id)

    if obj.order_side == "BUY_ORDER"
        # check if sufficient funds available
        cash = Mapper.getCash(obj.acct_id)
        if cash ≥ obj.limit_price * obj.limit_size
            # remove cash
            updated_cash = cash - (obj.limit_price * obj.limit_size)
            Mapper.update_cash(obj.acct_id, updated_cash)
            # create and send order to OMS layer for fulfillment
            # TODO: create and return unique obj.order_id = transaction_id
            # TODO: add order_id to pendingorders
            order = LimitOrder(obj.ticker, obj.order_id, obj.order_side, obj.limit_price, obj.limit_size, obj.acct_id)
            processTradeBid(order) # TODO: integrate @asynch functionality
            return # return order.order_id?
        else
            throw(InsufficientFunds())            
        end
    else # if obj.order_side == "SELL_ORDER"
        # check if sufficient shares available
        holdings = Mapper.getHoldings(obj.acct_id)
        # TODO: Implement short-selling functionality
        ticker = obj.ticker
        shares_owned = get(holdings, Symbol("$ticker"), 0) 
        if shares_owned ≥ obj.limit_size
            # remove shares
            updated_shares = shares_owned - obj.limit_size
            tick_key = (Symbol(ticker),)
            share_val = (updated_shares,)
            new_holdings = (; zip(tick_key, share_val)...)
            updated_holdings = merge(holdings, new_holdings)
            Mapper.update_holdings(obj.acct_id, updated_holdings)
            # create and send order to OMS layer for fulfillment
            # TODO: create and return unique obj.order_id = transaction_id
            # TODO: add order_id to pendingorders
            order = LimitOrder(obj.ticker, obj.order_id, obj.order_side, obj.limit_price, obj.limit_size, obj.acct_id)
            processTradeAsk(order) # TODO: integrate @asynch functionality
            return # return order.order_id?
        else
            throw(InsufficientShares())            
        end
    end
end

function placeMarketOrder(obj)
    @assert haskey(obj, :ticker) && !isempty(obj.ticker)
    @assert haskey(obj, :order_id) && !isempty(obj.order_id) # TODO: make this service-managed
    @assert haskey(obj, :order_side) && !isempty(obj.order_side)
    @assert haskey(obj, :fill_amount) && obj.fill_amount > zero(obj.fill_amount) 
    @assert haskey(obj, :acct_id) && !isempty(obj.acct_id)

    if obj.byfunds == false
        # administer market order by shares
        if obj.order_side == "BUY_ORDER"
            # check if sufficient funds available
            cash = Mapper.getCash(obj.acct_id)
            best_ask = (getBidAsk(obj.ticker))[2]
            estimated_price = best_ask * obj.fill_amount
            if cash > estimated_price # TODO: Test the functionality here for robustness, asynch & liquidity could break this
                # remove cash
                updated_cash = cash - (estimated_price)
                Mapper.update_cash(obj.acct_id, updated_cash)
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                # TODO: add order_id to pendingorders
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id)
                processTradeBuy(order; estimated_price = estimated_price) # TODO: integrate @asynch functionality
                return
            else
                throw(InsufficientFunds())            
            end
        else # if obj.order_side == "SELL_ORDER"
            # check if sufficient shares available
            holdings = Mapper.getHoldings(obj.acct_id)
            # TODO: Implement short-selling functionality
            ticker = obj.ticker
            shares_owned = get(holdings, Symbol("$ticker"), 0)
            if shares_owned ≥ obj.fill_amount
                # remove shares
                updated_shares = shares_owned - obj.fill_amount
                tick_key = (Symbol(ticker),)
                share_val = (updated_shares,)
                new_holdings = (; zip(tick_key, share_val)...)
                updated_holdings = merge(holdings, new_holdings)
                Mapper.update_holdings(obj.acct_id, updated_holdings)
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                # TODO: add order_id to pendingorders
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id)
                processTradeSell(order) # TODO: integrate @asynch functionality
                return
            else
                throw(InsufficientShares())            
            end
        end
    else
        # administer market order by funds
        if obj.order_side == "BUY_ORDER"
            # check if sufficient funds available
            cash = Mapper.getCash(obj.acct_id)
            if cash ≥ obj.fill_amount
                # remove cash
                updated_cash = cash - (obj.fill_amount)
                Mapper.update_cash(obj.acct_id, updated_cash)
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                # TODO: add order_id to pendingorders
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id, obj.byfunds)
                processTradeBuy(order) # TODO: integrate @asynch functionality
                return
            else
                throw(InsufficientFunds())            
            end
        else # if obj.order_side == "SELL_ORDER"
            # check if sufficient shares available
            holdings = Mapper.getHoldings(obj.acct_id)
            # TODO: Implement short-selling functionality
            ticker = obj.ticker
            best_ask = (getBidAsk(obj.ticker))[2]
            shares_owned = get(holdings, Symbol("$ticker"), 0)
            current_share_value = shares_owned * best_ask
            if current_share_value > obj.fill_amount # TODO: Test the functionality here for robustness, asynch & liquidity could break this
                # remove estimated amount of shares to be sold
                estimated_shares = floor(Int64, ((obj.fill_amount / current_share_value) * shares_owned))
                updated_shares = shares_owned - estimated_shares
                tick_key = (Symbol(ticker),)
                share_val = (updated_shares,)
                new_holdings = (; zip(tick_key, share_val)...)
                updated_holdings = merge(holdings, new_holdings)
                Mapper.update_holdings(obj.acct_id, updated_holdings)
                # create and send order to OMS layer for fulfillment
                # TODO: create and return unique obj.order_id = transaction_id
                # TODO: add order_id to pendingorders
                order = MarketOrder(obj.ticker, obj.order_id, obj.order_side, obj.fill_amount, obj.acct_id, obj.byfunds)
                processTradeSell(order; estimated_shares = estimated_shares) # TODO: integrate @asynch functionality
                return
            else
                throw(InsufficientShares())            
            end
        end
    end
end

function placeCancelOrder(obj)
    @assert haskey(obj, :ticker) && !isempty(obj.ticker)
    @assert haskey(obj, :order_id) && !isempty(obj.order_id)
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

function getMidPrice(ticker)
    bid, ask = OMS.queryBidAsk(ticker)
    mid_price = (ask + bid) / 2.0
    return mid_price
end

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

struct PlacementFailure <: Exception end
struct OrderInsertionError <: Exception end
struct LiquidityError <: Exception end
struct OrderNotFound <: Exception end

function processTradeBid(order::LimitOrder)
    trade = OMS.processLimitOrderPurchase(order)
    new_open_order = trade[1]
    cross_match_lst = trade[2]
    remaining_size = trade[3]

    if remaining_size !== zero(order.limit_size)
        # TODO: delete from pendingorders and apply refund
        # TODO: return the matched order(s) back to the LOB
        throw(OrderInsertionError("order could neither be inserted nor matched"))
    elseif new_open_order !== nothing && isempty(cross_match_lst) == true
        @info "Your order has been received and routed to the Exchange."
        return
    elseif new_open_order === nothing
        # update portfolio holdings{tickers, shares} of buyer
        holdings = Mapper.getHoldings(order.acct_id)
        ticker = order.ticker
        shares_owned = get(holdings, Symbol("$ticker"), 0)
        new_shares = order.limit_size + shares_owned
        tick_key = (Symbol(ticker),)
        share_val = (new_shares,)
        new_holdings = (; zip(tick_key, share_val)...)
        updated_holdings = merge(holdings, new_holdings)
        Mapper.update_holdings(order.acct_id, updated_holdings)
        # TODO: remove from pendingorders and add to completedorders

        # update portfolio cash of matched seller(s)
        for i in 1:length(cross_match_lst)
            matched_order = cross_match_lst[i]
            # update portfolio if order is native to Brokerage (i.e., not from a market maker)
            if matched_order.acctid > Mapper.MM_COUNTER
                earnings = matched_order.size * order.limit_price # crossed order clears at bid price
                cash = Mapper.getCash(matched_order.acctid)
                updated_cash = earnings + cash
                Mapper.update_cash(matched_order.acctid, updated_cash)
                # TODO: remove from matched_order.orderid pendingorders and into completedorders
            else
                continue
            end
        end

        @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order was crossed and your account has been updated."
        return
    elseif new_open_order !== nothing && isempty(cross_match_lst) == false
        # TODO (low-priority): implement functionality for this
        @info "Trade partially fulfilled at $(Dates.now(Dates.UTC)). Your order was partially crossed and your account has been updated."
        # TODO: delete from pendingorders and apply refund
        # TODO: return the matched order(s) back to the LOB
        throw(PlacementFailure("partially crossed limit orders not supported at this time"))
    else
        # TODO: delete from pendingorders and apply refund
        # TODO: return the matched order(s) back to the LOB
        throw(PlacementFailure())
    end
end

function processTradeAsk(order::LimitOrder)
    trade = OMS.processLimitOrderSale(order)
    new_open_order = trade[1]
    cross_match_lst = trade[2]
    remaining_size = trade[3]
    
    if remaining_size !== zero(order.limit_size)
        throw(OrderInsertionError("order could neither be inserted nor matched"))
    elseif new_open_order !== nothing && isempty(cross_match_lst) == true
        @info "Your order has been received and routed to the Exchange."
        return
    elseif new_open_order === nothing
        # update portfolio cash of seller
        earnings = order.limit_size * order.limit_price
        cash = Mapper.getCash(order.acct_id)
        updated_cash = earnings + cash
        Mapper.update_cash(order.acct_id, updated_cash)
        # TODO: remove from pendingorders and add to completedorders

        # update portfolio holdings{tickers, shares} of matched buyer(s)
        for i in 1:length(cross_match_lst)
            matched_order = cross_match_lst[i]
            # update portfolio if order is native to Brokerage (i.e., not from a market maker)
            if matched_order.acctid > Mapper.MM_COUNTER
                holdings = Mapper.getHoldings(matched_order.acctid)
                ticker = order.ticker
                shares_owned = get(holdings, Symbol("$ticker"), 0)
                new_shares = matched_order.size + shares_owned
                tick_key = (Symbol(ticker),)
                share_val = (new_shares,)
                new_holdings = (; zip(tick_key, share_val)...)
                updated_holdings = merge(holdings, new_holdings)
                Mapper.update_holdings(matched_order.acctid, updated_holdings)
                # TODO: remove from matched_order.orderid pendingorders and into completedorders
            else
                continue
            end
        end

        @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order was crossed and your account has been updated."
        return
    elseif new_open_order !== nothing && isempty(cross_match_lst) == false
        @info "Trade partially fulfilled at $(Dates.now(Dates.UTC)). Your order was partially crossed and your account has been updated."
        # TODO (low-priority): implement functionality for this
        throw(PlacementFailure("partially crossed limit orders not supported at this time"))
    else
        throw(PlacementFailure())
    end
end

function processTradeBuy(order::MarketOrder; estimated_price = 0.0)
    # navigate order by share amount or cash amount
    if order.byfunds == false
        # process order by shares
        trade = OMS.processMarketOrderPurchase(order)
        order_match_lst = trade[1]
        shares_leftover = trade[2]
        cash = Mapper.getCash(order.acct_id)
        cash_owed = 0.0
        for i in 1:length(order_match_lst)
            matched_order = order_match_lst[i]
            cash_owed += matched_order.size * matched_order.price
        end

        if cash_owed > (cash + estimated_price)
            # TODO: delete from pendingorders and apply `estimated_price` refund
            # TODO: return the matched order(s) back to the LOB
            throw(LiquidityError("Cash owed exceeds account balance. Order canceled."))
        else
            # balance cash of buyer
            price_adjustment = cash_owed - estimated_price
            updated_cash = cash - price_adjustment
            Mapper.update_cash(order.acct_id, updated_cash)
            # update portfolio holdings{tickers, shares} of buyer
            holdings = Mapper.getHoldings(order.acct_id)
            ticker = order.ticker
            shares_owned = get(holdings, Symbol("$ticker"), 0)
            shares_bought = order.share_amount - shares_leftover
            new_shares = shares_owned + shares_bought
            tick_key = (Symbol(ticker),)
            share_val = (new_shares,)
            new_holdings = (; zip(tick_key, share_val)...)
            updated_holdings = merge(holdings, new_holdings)
            Mapper.update_holdings(order.acct_id, updated_holdings)
            # TODO: remove from pendingorders and add to completedorders

            # update portfolio cash of matched seller(s)
            for i in 1:length(order_match_lst)
                matched_order = order_match_lst[i]
                # check if order is native to Brokerage (e.g., not from a market maker)
                if matched_order.acctid > Mapper.MM_COUNTER
                    earnings = matched_order.size * matched_order.price
                    cash = Mapper.getCash(matched_order.acctid)
                    updated_cash = earnings + cash
                    Mapper.update_cash(matched_order.acctid, updated_cash)
                    # TODO: remove from matched_order.orderid pendingorders and into completedorders
                else
                    continue
                end
            end

            # send confirmation message
            if shares_leftover === zero(order.share_amount)
                @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
                return
            else
                @info "Trade partially fulfilled at $(Dates.now(Dates.UTC)). Only $(shares_bought) out of $(order.share_amount) were able to be purchased. Your account has been updated."
                return
            end
        end
    else 
        # process by funds
        trade = OMS.processMarketOrderPurchase_byfunds(order)
        order_match_lst = trade[1]
        funds_leftover = trade[2]
        shares_bought = 0
        for i in 1:length(order_match_lst)
            matched_order = order_match_lst[i]
            shares_bought += matched_order.size
        end

        # update portfolio holdings{tickers, shares} of buyer
        holdings = Mapper.getHoldings(order.acct_id)
        ticker = order.ticker
        shares_owned = get(holdings, Symbol("$ticker"), 0)
        updated_shares = shares_bought + shares_owned
        tick_key = (Symbol(ticker),)
        share_val = (updated_shares,)
        new_holdings = (; zip(tick_key, share_val)...)
        updated_holdings = merge(holdings, new_holdings)
        Mapper.update_holdings(order.acct_id, updated_holdings)
        # TODO: remove from pendingorders and add to completedorders

        # update portfolio cash of matched seller(s)
        for i in 1:length(order_match_lst)
            matched_order = order_match_lst[i]
            # check if order is native to Brokerage (e.g., not from a market maker)
            if matched_order.acctid > Mapper.MM_COUNTER
                earnings = matched_order.size * matched_order.price
                cash = Mapper.getCash(matched_order.acctid)
                updated_cash = earnings + cash
                Mapper.update_cash(matched_order.acctid, updated_cash)
                # TODO: remove from matched_order.orderid pendingorders and into completedorders
            else
                continue
            end
        end

        # confirmation process
        if funds_leftover === zero(order.cash_amount)
            @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
            return
        else
            # partial fill - refund remaining funds
            cash = Mapper.getCash(order.acct_id)
            updated_cash = cash + funds_leftover
            Mapper.update_cash(order.acct_id, updated_cash)
            @info "Trade partially fulfilled at $(Dates.now(Dates.UTC)). You were refunded \$ $(funds_leftover). Your account has been updated."
            return
        end
    end
end

function processTradeSell(order::MarketOrder; estimated_shares = 0)
    # navigate order by share amount or cash amount
    if order.byfunds == false
        # process order by share amount
        trade = OMS.processMarketOrderSale(order)
        order_match_lst = trade[1]
        shares_leftover = trade[2]
        earnings = 0.0
        for i in 1:length(order_match_lst)
            matched_order = order_match_lst[i]
            earnings += matched_order.size * matched_order.price
        end

        # update portfolio cash of seller
        cash = Mapper.getCash(order.acct_id)
        updated_cash = cash + earnings
        Mapper.update_cash(order.acct_id, updated_cash)
        # TODO: remove from pendingorders and add to completedorders

        # update portfolio holdings{tickers, shares} of matched buyer(s)
        for i in 1:length(order_match_lst)
            matched_order = order_match_lst[i]
            # check if order is native to Brokerage (e.g., not from a market maker)
            if matched_order.acctid > Mapper.MM_COUNTER
                holdings = Mapper.getHoldings(matched_order.acctid)
                ticker = order.ticker
                shares_owned = get(holdings, Symbol("$ticker"), 0)
                new_shares = matched_order.size + shares_owned
                tick_key = (Symbol(ticker),)
                share_val = (new_shares,)
                new_holdings = (; zip(tick_key, share_val)...)
                updated_holdings = merge(holdings, new_holdings)
                Mapper.update_holdings(matched_order.acctid, updated_holdings)
                # TODO: remove from matched_order.orderid pendingorders and into completedorders
            else
                continue
            end
        end

        # confirmation process
        if shares_leftover === zero(order.share_amount)
            @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
            return
        else
            # partial fill - refund remaining shares
            holdings = Mapper.getHoldings(order.acct_id)
            ticker = order.ticker
            shares_owned = get(holdings, Symbol("$ticker"), 0)
            new_shares = shares_leftover + shares_owned
            tick_key = (Symbol(ticker),)
            share_val = (new_shares,)
            new_holdings = (; zip(tick_key, share_val)...)
            updated_holdings = merge(holdings, new_holdings)
            Mapper.update_holdings(order.acct_id, updated_holdings)
            @info "Trade partially fulfilled at $(Dates.now(Dates.UTC)). You were refunded $(shares_leftover) shares. Your account has been updated."
            return
        end
    else
        # process by funds
        trade = OMS.processMarketOrderSale_byfunds(order)
        order_match_lst = trade[1]
        funds_leftover = trade[2]
        holdings = Mapper.getHoldings(order.acct_id)
        ticker = order.ticker
        shares_held = get(holdings, Symbol("$ticker"), 0)
        shares_owed = 0
        for i in 1:length(order_match_lst)
            matched_order = order_match_lst[i]
            shares_owed += matched_order.size
        end

        if shares_owed > (shares_held + estimated_shares)
            # TODO: delete from pendingorders and apply `estimated_shares` refund
            # TODO: return the matched order(s) back to the LOB
            throw(LiquidityError("Shares owed exceeds account holdings. Order canceled."))
        else
            # balance shares of seller
            share_adjustment = shares_owed - estimated_shares
            updated_shares = shares_held - share_adjustment
            tick_key = (Symbol(ticker),)
            share_val = (updated_shares,)
            new_holdings = (; zip(tick_key, share_val)...)
            updated_holdings = merge(holdings, new_holdings)
            Mapper.update_holdings(order.acct_id, updated_holdings)
            # update portfolio cash of seller
            cash = Mapper.getCash(order.acct_id)
            earnings = order.cash_amount - funds_leftover
            updated_cash = cash + earnings
            Mapper.update_cash(order.acct_id, updated_cash)
            # TODO: remove from pendingorders and add to completedorders

            # update portfolio holdings{tickers, shares} of matched buyer(s)
            for i in 1:length(order_match_lst)
                matched_order = order_match_lst[i]
                # check if order is native to Brokerage (e.g., not from a market maker)
                if matched_order.acctid > Mapper.MM_COUNTER
                    holdings = Mapper.getHoldings(matched_order.acctid)
                    ticker = order.ticker
                    shares_owned = get(holdings, Symbol("$ticker"), 0)
                    new_shares = matched_order.size + shares_owned
                    tick_key = (Symbol(ticker),)
                    share_val = (new_shares,)
                    new_holdings = (; zip(tick_key, share_val)...)
                    updated_holdings = merge(holdings, new_holdings)
                    Mapper.update_holdings(matched_order.acctid, updated_holdings)
                    # TODO: remove from matched_order.orderid pendingorders and into completedorders
                else
                    continue
                end
            end

            # send confirmation message
            if funds_leftover === zero(order.cash_amount)
                @info "Trade fulfilled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
                return
            else
                @info "Trade partially fulfilled at $(Dates.now(Dates.UTC)). Only \$ $(earnings) out of \$ $(order.cash_amount) worth of shares were sold. Your account has been updated."
                return
            end
        end
    end
end

function cancelTrade(order::CancelOrder)
    # navigate order to correct location
    if order.order_side == "SELL_ORDER"
        canceled_trade = OMS.cancelLimitOrderSale(order)
        if canceled_trade !== nothing && canceled_trade.acctid > Mapper.MM_COUNTER
            # refund shares
            holdings = Mapper.getHoldings(order.acct_id)
            ticker = order.ticker
            shares_owned = get(holdings, Symbol("$ticker"), 0)
            updated_shares = shares_owned + canceled_trade.size
            tick_key = (Symbol(ticker),)
            share_val = (updated_shares,)
            new_holdings = (; zip(tick_key, share_val)...)
            updated_holdings = merge(holdings, new_holdings)
            Mapper.update_holdings(order.acct_id, updated_holdings)
            # TODO: delete canceled_trade.orderid from pendingorders

            # send confirmation
            @info "Trade canceled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
            return
        elseif canceled_trade !== nothing && canceled_trade.acctid ≤ Mapper.MM_COUNTER
            throw(OrderNotFound("unauthorized attempt to cancel non-native order"))
        else
            throw(OrderNotFound())
        end
    else 
        # order.order_side == "BUY_ORDER"
        canceled_trade = OMS.cancelLimitOrderPurchase(order)
        if canceled_trade !== nothing && canceled_trade.acctid > Mapper.MM_COUNTER
            # refund cash
            cash = Mapper.getCash(order.acct_id)
            refund = canceled_trade.size * canceled_trade.price
            updated_cash = cash + refund
            Mapper.update_cash(order.acct_id, updated_cash)
            # TODO: delete canceled_trade.orderid from pendingorders

            # send confirmation
            @info "Trade canceled at $(Dates.now(Dates.UTC)). Your order is complete and your account has been updated."
            return
        elseif canceled_trade !== nothing && canceled_trade.acctid ≤ Mapper.MM_COUNTER
            throw(OrderNotFound("unauthorized attempt to cancel non-native order"))
        else
            throw(OrderNotFound())
        end
    end
end

# TODO: Other info messages (examples below)

# "Update (timestamp): Your order to sell 100 shares of NOK has been filled at an average price of $4.01 per share. Your order is complete."

# "We've received your order to open 1 MVIS Call Credit Spread at a minimum of $0.40 per unit. If this order isn't filled by the end of market hours today (4pm ET), it'll be canceled."
# "Your order to open 1 MVIS Call Credit Spread wasn't filled today, and has been automatically canceled."

# "Your order to sell to close 1 contract of T $29.50 Call 4/1 has been filled for an average price of $94.00 per contract. Your order is complete."

# "Update: Because you owned 0.526674 shares of NVDA on 6/8, you've received a dividend payment of $0.02."

# ======================================================================================== #
#----- Market Maker Services -----#

function provideLiquidity(order)
    liquidity_order = OMS.provideLiquidity(order)
    # send confirmation
    @info "Liquidity order completed. $(order.order_side) quote processed."
    return
end

end # module