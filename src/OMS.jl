module OMS
# Order Management Systems (OMS) - order processing and interface with Exchange service layer

using ..Model
using VLLimitOrderBook, Dates, CSV, DataFrames, Random, DataStructures

const NUM_ASSETS = Ref{Int64}(0)
const PRICE_BUFFER_CAPACITY = Ref{Int64}(0)
const ORDER_ID_COUNTER = Ref{Int64}(0)

# ======================================================================================== #
#----- LOB INITIALIZATION -----#

# Create (Deterministic) Limit Order Generator
MyOrderSubTypes = (Int64,Float64,Int64,Int64) # define types for Order Size, Price, Order IDs, Account IDs
MyLOBType = OrderBook{MyOrderSubTypes...}
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

# Initialize Limit Order Book(s)
function init_LOB!(ob, LP_order_vol, LP_cancel_vol, trade_volume_t, price_buffer)
    @info "Connecting to Exchange and initializing Limit Order Book..."
    N = NUM_ASSETS[]
    for ticker in 1:N
        # Create order book for specific ticker
        ob_tick = MyLOBType() # Initialize empty order book
        # fill book with random limit orders
        for i=1:20
            # add some limit orders (near top of book)
            submit_limit_order!(ob_tick,init_orderid,BUY_ORDER,99.0-randspread_small(),rand(5:5:20),init_acctid)
            submit_limit_order!(ob_tick,init_orderid,SELL_ORDER,99.0+randspread_small(),rand(5:5:20),init_acctid)
            # add some limit orders (to increase mid-range depth of book)
            submit_limit_order!(ob_tick,init_orderid,BUY_ORDER,99.0-randspread_mid(),rand(10:10:100),init_acctid)
            submit_limit_order!(ob_tick,init_orderid,SELL_ORDER,99.0+randspread_mid(),rand(10:10:100),init_acctid)
            # add some limit orders (to increase long-range depth of book)
            submit_limit_order!(ob_tick,init_orderid,BUY_ORDER,99.0-randspread_large(),rand(50:50:500),init_acctid)
            submit_limit_order!(ob_tick,init_orderid,SELL_ORDER,99.0+randspread_large(),rand(50:50:500),init_acctid)
            if (rand() < 0.1) # and some market orders
                submit_market_order!(ob_tick,rand_side(),rand(10:25:150))
            end
        end
        push!(ob, ob_tick)
        # append liquidity provider data structures
        push!(LP_order_vol, zeros(Int64, 4))
        push!(LP_cancel_vol, zeros(Int64, 4))
        push!(trade_volume_t, 0)
        # create and store circular buffer for specific ticker
        price_buffer_tick = CircularBuffer{Float64}(PRICE_BUFFER_CAPACITY[])
        push!(price_buffer, price_buffer_tick)
    end
    @info "Exchange Connection successful. Limit Order Book initialization sequence complete."
end

# ======================================================================================== #
#----- Data Collection -----#

# create data collection vectors for recording liquidity taker activity
ticker_symbol = Int[]
tick_time = DateTime[]
tick_bid_prices = Float64[]
tick_ask_prices = Float64[]
tick_last_prices = Float64[]
tick_trading_volume = Float64[]

# create quote data DataFrame for recording liquidity provider activity
LP_order_vol = DataFrame(n_buy=Int[],n_sell=Int[],buy_vol=Int[],sell_vol=Int[])
LP_cancel_vol = DataFrame(n_cbuy=Int[],n_csell=Int[],cbuy_vol=Int[],csell_vol=Int[])

# create trade volume Vector for liquidity providers (indexed by ticker)
trade_volume_t = Int[]

# create dynamic price series vector (indexed by ticker)
price_buffer = Vector{CircularBuffer{Float64}}()

# post-simulation data collection methods
function collect_tick_data(ticker, bid, ask, last_price, shares_traded)
    push!(ticker_symbol, ticker)
    timestamp = Dates.now()
    push!(tick_time, timestamp)
    push!(tick_bid_prices, bid)
    push!(tick_ask_prices, ask)
    push!(tick_last_prices, last_price)
    push!(tick_trading_volume, shares_traded)
end

function write_market_data(ticker_symbol, tick_time, tick_bid_prices,
                    tick_ask_prices, tick_last_prices, tick_trading_volume)
    # prepare tabular dataset
    market_data = DataFrame(ticker = ticker_symbol, timestamp = tick_time,
                bid_prices = tick_bid_prices, ask_prices = tick_ask_prices,
                last_prices = tick_last_prices, trading_volume = tick_trading_volume)
    # Create save path
    savepath = mkpath("../../Data/ABMs/Brokerage")
    # Save data
    CSV.write("$(savepath)/market_data.csv", market_data)
end

# Additional data utility functions
total_ask_price_levels(ticker::Int) = size((ob[ticker]).ask_orders.book)
total_bid_price_levels(ticker::Int) = size((ob[ticker]).bid_orders.book)
ntotal_price_levels(ticker::Int) = (size((ob[ticker]).bid_orders.book), size((ob[ticker]).ask_orders.book))

function write_LP_data(LP_order_vol, LP_cancel_vol)
    # prepare price level dataset
    N = NUM_ASSETS[]
    price_level_df = DataFrame(n_bid_levels = zeros(Int64,N), n_ask_levels = zeros(Int64,N))
    for ticker in 1:N
        last_bpl, last_apl = ntotal_price_levels(ticker)
        price_level_df[ticker, 1] = last_bpl
        price_level_df[ticker, 2] = last_apl
    end
    # join datasets
    LP_df = hcat(LP_order_vol, LP_cancel_vol)
    LP_df = hcat(LP_df, price_level_df)
    # Create save path
    savepath = mkpath("../../Data/ABMs/Brokerage")
    # Save data
    CSV.write("$(savepath)/LP_data.csv", LP_df)
end

# ======================================================================================== #
#----- Trade Processing -----#

function processLimitOrderSale(order::LimitOrder)
    order_id = (ORDER_ID_COUNTER[] += 1) * -1
    limit_price = order.limit_price
    limit_size = order.limit_size
    acct_id = order.acct_id
    trade = VLLimitOrderBook.submit_limit_order!(ob[order.ticker],
                        order_id, SELL_ORDER, limit_price,
                        limit_size, acct_id)
    return trade
end

function processLimitOrderPurchase(order::LimitOrder)
    order_id = ORDER_ID_COUNTER[] += 1
    limit_price = order.limit_price
    limit_size = order.limit_size
    acct_id = order.acct_id
    trade = VLLimitOrderBook.submit_limit_order!(ob[order.ticker],
                        order_id, BUY_ORDER, limit_price,
                        limit_size, acct_id)
    return trade
end

function processMarketOrderSale(order::MarketOrder)
    trade = VLLimitOrderBook.submit_market_order!(ob[order.ticker],SELL_ORDER,
                        order.share_amount)
    # collect market data
    bid, ask = VLLimitOrderBook.best_bid_ask(ob[order.ticker])
    order_match_lst = trade[1]
    last_price = (last(order_match_lst)).price
    shares_leftover = trade[2]
    shares_traded = order.share_amount - shares_leftover
    collect_tick_data(order.ticker, bid, ask, last_price, shares_traded)
    trade_volume_t[order.ticker] += shares_traded
    pushfirst!(price_buffer[order.ticker], last_price)
    return order_match_lst, shares_leftover
end

function processMarketOrderPurchase(order::MarketOrder)
    trade = VLLimitOrderBook.submit_market_order!(ob[order.ticker],BUY_ORDER,
                        order.share_amount)
    # collect market data
    bid, ask = VLLimitOrderBook.best_bid_ask(ob[order.ticker])
    order_match_lst = trade[1]
    last_price = (last(order_match_lst)).price
    shares_leftover = trade[2]
    shares_traded = order.share_amount - shares_leftover
    collect_tick_data(order.ticker, bid, ask, last_price, shares_traded)
    trade_volume_t[order.ticker] += shares_traded
    pushfirst!(price_buffer[order.ticker], last_price)
    return order_match_lst, shares_leftover
end

function processMarketOrderSale_byfunds(order::MarketOrder)
    trade = VLLimitOrderBook.submit_market_order_byfunds!(ob[order.ticker],SELL_ORDER,
                        order.cash_amount)
    # collect market data
    bid, ask = VLLimitOrderBook.best_bid_ask(ob[order.ticker])
    order_match_lst = trade[1]
    last_price = (last(order_match_lst)).price
    shares_traded = 0
    for i in eachindex(order_match_lst)
        matched_order = order_match_lst[i]
        shares_traded += matched_order.size
    end
    collect_tick_data(order.ticker, bid, ask, last_price, shares_traded)
    trade_volume_t[order.ticker] += shares_traded
    pushfirst!(price_buffer[order.ticker], last_price)
    return trade
end

function processMarketOrderPurchase_byfunds(order::MarketOrder)
    trade = VLLimitOrderBook.submit_market_order_byfunds!(ob[order.ticker],BUY_ORDER,
                        order.cash_amount)
    # collect market data
    bid, ask = VLLimitOrderBook.best_bid_ask(ob[order.ticker])
    order_match_lst = trade[1]
    last_price = (last(order_match_lst)).price
    shares_traded = 0
    for i in eachindex(order_match_lst)
        matched_order = order_match_lst[i]
        shares_traded += matched_order.size
    end
    collect_tick_data(order.ticker, bid, ask, last_price, shares_traded)
    trade_volume_t[order.ticker] += shares_traded
    pushfirst!(price_buffer[order.ticker], last_price)
    return trade
end

function cancelLimitOrderSale(order::CancelOrder)
    canceled_order = VLLimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        SELL_ORDER,order.limit_price)
    return canceled_order
end

function cancelLimitOrderPurchase(order::CancelOrder)
    canceled_order = VLLimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        BUY_ORDER,order.limit_price)
    return canceled_order
end

# ======================================================================================== #
#----- Order Book Processing -----#

function queryBidAsk(ticker)
    top_book = VLLimitOrderBook.best_bid_ask(ob[ticker])
    return top_book
end

function queryBookDepth(ticker)
    depth = VLLimitOrderBook.book_depth_info(ob[ticker])
    return depth
end

function queryBidAskVolume(ticker)
    book_volume = VLLimitOrderBook.volume_bid_ask(ob[ticker])
    return book_volume
end

function queryBidAskOrders(ticker)
    n_orders_book = VLLimitOrderBook.n_orders_bid_ask(ob[ticker])
    return n_orders_book
end

function queryPriceSeries(ticker)
    price_list = convert(Vector{Float64}, price_buffer[ticker])
    return price_list
end

# ======================================================================================== #
#----- Market Maker Processing -----#

function provideLiquidity(order)
    if order.order_side == "BUY_ORDER"
        order_id = ORDER_ID_COUNTER[] += 1
        VLLimitOrderBook.submit_limit_order!(ob[order.ticker],
                        order_id, BUY_ORDER, order.limit_price,
                        order.limit_size, order.acct_id)
        LP_order_vol[order.ticker, 1] += 1
        LP_order_vol[order.ticker, 3] += order.limit_size

        if order.send_id == false
            return
        else
            return order_id
        end
    else
        # order.order_side == "SELL_ORDER"
        order_id = (ORDER_ID_COUNTER[] += 1) * -1
        VLLimitOrderBook.submit_limit_order!(ob[order.ticker],
                        order_id, SELL_ORDER, order.limit_price,
                        order.limit_size, order.acct_id)
        LP_order_vol[order.ticker, 2] += 1
        LP_order_vol[order.ticker, 4] += order.limit_size

        if order.send_id == false
            return
        else
            return order_id
        end
    end
end

function hedgeTrade(order)
    if order.order_side == "BUY_ORDER"
        trade = VLLimitOrderBook.submit_market_order!(ob[order.ticker],BUY_ORDER,
                        order.fill_amount)
        # collect market data
        bid, ask = VLLimitOrderBook.best_bid_ask(ob[order.ticker])
        order_match_lst = trade[1]
        last_price = (last(order_match_lst)).price
        shares_leftover = trade[2]
        shares_traded = order.fill_amount - shares_leftover
        collect_tick_data(order.ticker, bid, ask, last_price, shares_traded)
        trade_volume_t[order.ticker] += shares_traded
        pushfirst!(price_buffer[order.ticker], last_price)
    else
        # order.order_side == "SELL_ORDER"
        trade = VLLimitOrderBook.submit_market_order!(ob[order.ticker],SELL_ORDER,
                        order.fill_amount)
        # collect market data
        bid, ask = VLLimitOrderBook.best_bid_ask(ob[order.ticker])
        order_match_lst = trade[1]
        last_price = (last(order_match_lst)).price
        shares_leftover = trade[2]
        shares_traded = order.fill_amount - shares_leftover
        collect_tick_data(order.ticker, bid, ask, last_price, shares_traded)
        trade_volume_t[order.ticker] += shares_traded
        pushfirst!(price_buffer[order.ticker], last_price)
    end
 
    return
end

function queryTradeVolume(ticker)
    trade_volume = trade_volume_t[ticker]
    return trade_volume
end

function getOrderList(acct_id, ticker)
    order_list = VLLimitOrderBook.get_acct(ob[ticker], acct_id)
    return order_list    
end

function cancelSellQuote(order)
    canceled_order = VLLimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        SELL_ORDER,order.limit_price)
    if canceled_order !== nothing
        LP_cancel_vol[order.ticker, 2] += 1
        LP_cancel_vol[order.ticker, 4] += canceled_order.size
    end
    return
end

function cancelBuyQuote(order)
    canceled_order = VLLimitOrderBook.cancel_order!(ob[order.ticker],order.order_id,
                        BUY_ORDER,order.limit_price)
    if canceled_order !== nothing
        LP_cancel_vol[order.ticker, 1] += 1
        LP_cancel_vol[order.ticker, 3] += canceled_order.size
    end
    return
end

end # module