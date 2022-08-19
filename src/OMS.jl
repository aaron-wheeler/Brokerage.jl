module OMS
# Order Management Systems (OMS) - order processing and interface with Exchange service layer

using ..Model
using VL_LimitOrderBook, Dates, CSV, DataFrames, Random

const NUM_ASSETS = 2

# ======================================================================================== #
#----- LOB INITIALIZATION -----#

# Create (Deterministic) Limit Order Generator
@info "Connecting to Exchange and initializing Limit Order Book..."
# define types for Order Size, Price, Transcation ID, Account ID, Order Creation Time, IP Address, Port
MyUOBType = UnmatchedOrderBook{Int64, Float64, Int64, Int64, DateTime, String, Integer}
# define types for Order Size, Price, Order IDs, Account IDs
MyLOBType = OrderBook{Int64, Float64, Int64, Int64}
# define initialization params and methods
init_acctid = 0
init_orderid = 0
Random.seed!(12345)
randspread_small() = ceil(-0.05*log(rand()),digits=2)
randspread_mid() = ceil(-0.20*log(rand()),digits=2)
randspread_large() = ceil(-0.50*log(rand()),digits=2)
rand_side() = rand([BUY_ORDER,SELL_ORDER])

# Create and populate order book vectors
ob = Vector{OrderBook{Int64, Float64, Int64, Int64}}()
uob = Vector{UnmatchedOrderBook{Int64, Float64, Int64, Int64, DateTime, String, Integer}}()
for ticker in 1:NUM_ASSETS
    # Create order book for specific ticker
    ob_tick = MyLOBType() # Initialize empty order book
    uob_tick = MyUOBType() # Initialize unmatched book process
    # fill book with random limit orders
    for i=1:20
        # add some limit orders (near top of book)
        submit_limit_order!(ob_tick,uob_tick,init_orderid,BUY_ORDER,99.0-randspread_small(),rand(5:5:20),init_acctid)
        submit_limit_order!(ob_tick,uob_tick,init_orderid,SELL_ORDER,99.0+randspread_small(),rand(5:5:20),init_acctid)
        # add some limit orders (to increase mid-range depth of book)
        submit_limit_order!(ob_tick,uob_tick,init_orderid,BUY_ORDER,99.0-randspread_mid(),rand(10:10:100),init_acctid)
        submit_limit_order!(ob_tick,uob_tick,init_orderid,SELL_ORDER,99.0+randspread_mid(),rand(10:10:100),init_acctid)
        # add some limit orders (to increase long-range depth of book)
        submit_limit_order!(ob_tick,uob_tick,init_orderid,BUY_ORDER,99.0-randspread_large(),rand(50:50:500),init_acctid)
        submit_limit_order!(ob_tick,uob_tick,init_orderid,SELL_ORDER,99.0+randspread_large(),rand(50:50:500),init_acctid)
        if (rand() < 0.1) # and some market orders
            submit_market_order!(ob_tick,rand_side(),rand(10:25:150))
        end
    end
    push!(ob, ob_tick)
    push!(uob, uob_tick) 
end

@info "Exchange Connection successful. Limit Order Book initialization sequence complete."

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

# Additional data utility functions
total_ask_price_levels(ticker::Int) = size((ob[ticker]).ask_orders.book)
total_bid_price_levels(ticker::Int) = size((ob[ticker]).bid_orders.book)

# ======================================================================================== #
#----- Trade Processing -----#

function processLimitOrderSale(order::LimitOrder)
    order_id = order.order_id
    limit_price = order.limit_price
    limit_size = order.limit_size
    acct_id = order.acct_id
    trade = VL_LimitOrderBook.submit_limit_order!(ob[order.ticker], uob[order.ticker],
                        order_id, SELL_ORDER, limit_price,
                        limit_size, acct_id)
    return trade
end

function processLimitOrderPurchase(order::LimitOrder)
    order_id = order.order_id
    limit_price = order.limit_price
    limit_size = order.limit_size
    acct_id = order.acct_id
    trade = VL_LimitOrderBook.submit_limit_order!(ob[order.ticker], uob[order.ticker],
                        order_id, BUY_ORDER, limit_price,
                        limit_size, acct_id)
    return trade
end

function processMarketOrderSale(order::MarketOrder)
    trade = VL_LimitOrderBook.submit_market_order!(ob[order.ticker],SELL_ORDER,
                        order.share_amount)
    # collect market data
    shares_leftover = trade[2]
    shares_traded = order.share_amount - shares_leftover
    bid, ask = VL_LimitOrderBook.best_bid_ask(ob[order.ticker])
    collect_tick_data(order.ticker, bid, ask, shares_traded)
    return trade
end

function processMarketOrderPurchase(order::MarketOrder)
    trade = VL_LimitOrderBook.submit_market_order!(ob[order.ticker],BUY_ORDER,
                        order.share_amount)
    # collect market data
    shares_leftover = trade[2]
    shares_traded = order.share_amount - shares_leftover
    bid, ask = VL_LimitOrderBook.best_bid_ask(ob[order.ticker])
    collect_tick_data(order.ticker, bid, ask, shares_traded)
    return trade
end

function processMarketOrderSale_byfunds(order::MarketOrder)
    trade = VL_LimitOrderBook.submit_market_order_byfunds!(ob[order.ticker],SELL_ORDER,
                        order.cash_amount)
    return trade
end

function processMarketOrderPurchase_byfunds(order::MarketOrder)
    trade = VL_LimitOrderBook.submit_market_order_byfunds!(ob[order.ticker],BUY_ORDER,
                        order.cash_amount)
    return trade
end

function cancelLimitOrderSale(order::CancelOrder)
    canceled_order = VL_LimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        SELL_ORDER,order.limit_price)
    return canceled_order
end

function cancelLimitOrderPurchase(order::CancelOrder)
    canceled_order = VL_LimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        BUY_ORDER,order.limit_price)
    return canceled_order
end

# ======================================================================================== #
#----- Quote Processing -----#

function queryBidAsk(ticker)
    top_book = VL_LimitOrderBook.best_bid_ask(ob[ticker])
    return top_book
end

function queryBookDepth(ticker)
    depth = VL_LimitOrderBook.book_depth_info(ob[ticker])
    return depth
end

function queryBidAskVolume(ticker)
    book_volume = VL_LimitOrderBook.volume_bid_ask(ob[ticker])
    return book_volume
end

function queryBidAskOrders(ticker)
    n_orders_book = VL_LimitOrderBook.n_orders_bid_ask(ob[ticker])
    return n_orders_book
end

# ======================================================================================== #
#----- Market Maker Processing -----#

function provideLiquidity(order)
    if order.order_side == "BUY_ORDER"
        VL_LimitOrderBook.submit_limit_order!(ob[order.ticker], uob[order.ticker],
                        order.order_id, BUY_ORDER, order.limit_price,
                        order.limit_size, order.acct_id)
    else
        # order.order_side == "SELL_ORDER"
        VL_LimitOrderBook.submit_limit_order!(ob[order.ticker], uob[order.ticker],
                        order.order_id, SELL_ORDER, order.limit_price,
                        order.limit_size, order.acct_id)
    end
 
    return
end

function getOrderList(acct_id, ticker)
    order_list = VL_LimitOrderBook.get_acct(ob[ticker], acct_id)
    return order_list    
end

function cancelSellQuote(order)
    canceled_order = VL_LimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        SELL_ORDER,order.limit_price)
    return
end

function cancelBuyQuote(order)
    canceled_order = VL_LimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        BUY_ORDER,order.limit_price)
    return
end

end # module