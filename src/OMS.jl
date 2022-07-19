module OMS
# Order Management Systems (OMS) - order processing and interface with Exchange service layer

using ..Model
using VL_LimitOrderBook, Dates, CSV, DataFrames
using Base.Iterators: zip,cycle,take,filter

# ======================================================================================== #
#----- LOB INITIALIZATION -----#

# function init()
# Create (Deterministic) Limit Order Generator
@info "Connecting to Exchange and initializing Limit Order Book..."
# define types for Order Size, Price, Transcation ID, Account ID, Order Creation Time, IP Address, Port
MyUOBType = UnmatchedOrderBook{Float64, Float64, Int64, Int64, DateTime, String, Integer}
# define types for Order Size, Price, Order IDs, Account IDs
MyLOBType = OrderBook{Float64, Float64, Int64, Int64}
ob1 = MyLOBType() # Initialize empty order book
uob1 = MyUOBType() # Initialize unmatched book process

orderid_iter = Base.Iterators.countfrom(1)
sign_iter = cycle([1,-1,1,-1])
side_iter = ( s > 0 ? SELL_ORDER : BUY_ORDER for s in sign_iter )
spread_iter = cycle([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6]*1e-2)
price_iter = ( Float32(99.0 + sgn*δ) for (δ,sgn) in zip(spread_iter,sign_iter) )
size_iter = cycle([10, 11, 20, 21, 30, 31, 40, 41, 50, 51])
init_acctid = 0

# zip them all together
lmt_order_info_iter = zip(orderid_iter,price_iter,size_iter,side_iter)

# generate orders from the iterator
order_info_lst = take(lmt_order_info_iter,6)

# Create first order book
# Add a bunch of orders
for (orderid, price, size, side) in order_info_lst
    submit_limit_order!(ob1,uob1,orderid,side,price,size,init_acctid)
    print(orderid, ' ',side,' ',price,'\n')
end

# Create second order book
ob2 = MyLOBType() # Initialize empty order book
uob2 = MyUOBType() # Initialize unmatched book process
# fill book with random limit orders
randspread() = ceil(-0.05*log(rand()),digits=2)
rand_side() = rand([BUY_ORDER,SELL_ORDER])
for i=1:10
    # add some limit orders
    submit_limit_order!(ob2,uob2,2i,BUY_ORDER,99.0-randspread(),rand(5:5:20),init_acctid)
    submit_limit_order!(ob2,uob2,3i,SELL_ORDER,99.0+randspread(),rand(5:5:20),init_acctid)
    if (rand() < 0.1) # and some market orders
        submit_market_order!(ob2,rand_side(),rand(10:25:150))
    end
end

@info "Exchange Connection successful. Limit Order Book initialization sequence complete."
# end

# ======================================================================================== #
#----- Data Collection -----#

# create data collection vectors
ticker_symbol = Int[]
tick_time = DateTime[]
tick_bid_prices = Float64[]
tick_ask_prices = Float64[]
tick_trading_volume = Float64[]

# post-simulation data collection methods
function collect_tick_data(ticker, bid, ask, shares_traded)
    push!(ticker_symbol, ticker)
    timestamp = Dates.now()
    push!(tick_time, timestamp)
    push!(tick_bid_prices, bid)
    push!(tick_ask_prices, ask)
    push!(tick_trading_volume, shares_traded)
end

function write_market_data(ticker_symbol, tick_time, tick_bid_prices,
                            tick_ask_prices, tick_trading_volume)
    # prepare tabular dataset
    market_data = DataFrame(ticker = ticker_symbol, timestamp = tick_time,
                bid_prices = tick_bid_prices, ask_prices = tick_ask_prices,
                trading_volume = tick_trading_volume)
    # Create save path
    savepath = mkpath("../../Data/ABMs/Brokerage")
    # Save data
    CSV.write("$(savepath)/market_data.csv", market_data)
end

# ======================================================================================== #
#----- Trade Processing -----#

function processLimitOrderSale(order::LimitOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    uob_expr = Symbol("uob"*"$ticker_ob")
    order_id = order.order_id
    limit_price = order.limit_price
    limit_size = order.limit_size
    acct_id = order.acct_id
    trade = VL_LimitOrderBook.submit_limit_order!(eval(ob_expr), eval(uob_expr), order_id,
                        SELL_ORDER, limit_price,
                        limit_size, acct_id)
    return trade
end

function processLimitOrderPurchase(order::LimitOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    uob_expr = Symbol("uob"*"$ticker_ob")
    order_id = order.order_id
    limit_price = order.limit_price
    limit_size = order.limit_size
    acct_id = order.acct_id
    trade = VL_LimitOrderBook.submit_limit_order!(eval(ob_expr), eval(uob_expr), order_id,
                        BUY_ORDER, limit_price,
                        limit_size, acct_id)
    return trade
end

function processMarketOrderSale(order::MarketOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    trade = VL_LimitOrderBook.submit_market_order!(eval(ob_expr),SELL_ORDER,order.fill_amount)
    
    # collect market data
    shares_leftover = trade[2]
    shares_traded = order.fill_amount - shares_leftover
    bid, ask = VL_LimitOrderBook.best_bid_ask(eval(ob_expr))
    collect_tick_data(order.ticker, bid, ask, shares_traded)
    
    return trade
end

function processMarketOrderPurchase(order::MarketOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    trade = VL_LimitOrderBook.submit_market_order!(eval(ob_expr),BUY_ORDER,order.fill_amount)
    
    # collect market data
    shares_leftover = trade[2]
    shares_traded = order.fill_amount - shares_leftover
    bid, ask = VL_LimitOrderBook.best_bid_ask(eval(ob_expr))
    collect_tick_data(order.ticker, bid, ask, shares_traded)

    return trade
end

function processMarketOrderSale_byfunds(order::MarketOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    trade = VL_LimitOrderBook.submit_market_order_byfunds!(eval(ob_expr),SELL_ORDER,order.fill_amount)
    return trade
end

function processMarketOrderPurchase_byfunds(order::MarketOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    trade = VL_LimitOrderBook.submit_market_order_byfunds!(eval(ob_expr),BUY_ORDER,order.fill_amount)
    return trade
end

function cancelLimitOrderSale(order::CancelOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    canceled_order = VL_LimitOrderBook.cancel_order!(eval(ob_expr),order.order_id,SELL_ORDER,order.limit_price)
    return canceled_order
end

function cancelLimitOrderPurchase(order::CancelOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    canceled_order = VL_LimitOrderBook.cancel_order!(eval(ob_expr),order.order_id,BUY_ORDER,order.limit_price)
    return canceled_order
end

# ======================================================================================== #
#----- Quote Processing -----#

function queryBidAsk(ticker)
    ob_expr = Symbol("ob"*"$ticker")
    top_book = VL_LimitOrderBook.best_bid_ask(eval(ob_expr))
    return top_book
end

function queryBookDepth(ticker)
    ob_expr = Symbol("ob"*"$ticker")
    depth = VL_LimitOrderBook.book_depth_info(eval(ob_expr))
    return depth
end

function queryBidAskVolume(ticker)
    ob_expr = Symbol("ob"*"$ticker")
    book_volume = VL_LimitOrderBook.volume_bid_ask(eval(ob_expr))
    return book_volume
end

function queryBidAskOrders(ticker)
    ob_expr = Symbol("ob"*"$ticker")
    n_orders_book = VL_LimitOrderBook.n_orders_bid_ask(eval(ob_expr))
    return n_orders_book
end

# TODO: Consider implementing the following fn into `getPortfolio` function?
# VL_LimitOrderBook.get_acct(ob,acct_id) # returns an account map of all open orders assigned to account `acct_id`. The account map is implemented as a `Dict` containing `AVLTree`s.

# ======================================================================================== #
#----- Market Maker Processing -----#

function provideLiquidity(order)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    uob_expr = Symbol("uob"*"$ticker_ob")
    if order.order_side == "BUY_ORDER"
        VL_LimitOrderBook.submit_limit_order!(eval(ob_expr), eval(uob_expr),
                        order.order_id, BUY_ORDER, order.limit_price,
                        order.limit_size, order.acct_id)
    else
        # order.order_side == "SELL_ORDER"
        VL_LimitOrderBook.submit_limit_order!(eval(ob_expr), eval(uob_expr),
                        order.order_id, SELL_ORDER, order.limit_price,
                        order.limit_size, order.acct_id)
    end
 
    return
end

end # module