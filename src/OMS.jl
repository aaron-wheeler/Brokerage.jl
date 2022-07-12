module OMS
# Order Management Systems (OMS) - order processing and interface with Exchange service layer

using ..Model
using VL_LimitOrderBook, Dates
using Base.Iterators: zip,cycle,take,filter

# ======================================================================================== #
#----- LOB INITIALIZATION -----#

# function init()
# Create (Deterministic) Limit Order Generator
MyUOBType = UnmatchedOrderBook{Int64, Float64, Int64, Int64, DateTime, String, Integer} # define types for Order Size, Price, Transcation ID, Account ID, Order Creation Time, IP Address, Port
MyLOBType = OrderBook{Int64, Float64, Int64, Int64} # define types for Order Size, Price, Order IDs, Account IDs
ob1 = MyLOBType() # Initialize empty order book
uob1 = MyUOBType() # Initialize unmatched book process

orderid_iter = Base.Iterators.countfrom(1)
sign_iter = cycle([1,-1,1,-1])
side_iter = ( s > 0 ? SELL_ORDER : BUY_ORDER for s in sign_iter )
spread_iter = cycle([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6]*1e-2)
price_iter = ( Float32(99.0 + sgn*δ) for (δ,sgn) in zip(spread_iter,sign_iter) )
size_iter = cycle([10, 11, 20, 21, 30, 31, 40, 41, 50, 51])

# zip them all together
lmt_order_info_iter = zip(orderid_iter,price_iter,size_iter,side_iter)

order_info_lst = take(lmt_order_info_iter,6)

# Add a bunch of orders
@info "Connecting to Exchange and initializing Limit Order Book..."
for (orderid, price, size, side) in order_info_lst
    submit_limit_order!(ob1,uob1,orderid,side,price,size,10101)
    print(orderid, ' ',side,' ',price,'\n')
end
@info "Exchange Connection successful. Limit Order Book initialization sequence complete."
    
# end

# ======================================================================================== #
#----- Trade Services -----#

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
    # returns Tuple with 3 elements - new_open_order, cross_match_lst, remaining_size
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
    # returns Tuple with 3 elements - new_open_order, cross_match_lst, remaining_size
    return trade
end

function processMarketOrderSale(order::MarketOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    # determine whether to submit order by share ammount or cash ammount
    if order.byfunds == false
        trade = VL_LimitOrderBook.submit_market_order!(eval(ob_expr),SELL_ORDER,order.fill_amount)
    else
        trade = VL_LimitOrderBook.submit_market_order_byfunds!(eval(ob_expr),SELL_ORDER,order.fill_amount)
    end
    # returns Tuple with 2 elements - ord_lst (list of limit orders that the m_order matched with), left_to_trade (remaining size of un-filled order)
    # OR 
    # returns Tuple with 2 elements - ord_lst, funds_leftover (the amount of remaining funds if not enough liquidity was available)
    return trade
end

function processMarketOrderPurchase(order::MarketOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    # determine whether to submit order by share ammount or cash ammount
    if order.byfunds == false
        trade = VL_LimitOrderBook.submit_market_order!(eval(ob_expr),BUY_ORDER,order.fill_amount)
    else
        trade = VL_LimitOrderBook.submit_market_order_byfunds!(eval(ob_expr),BUY_ORDER,order.fill_amount)
    end
    # returns Tuple with 2 elements - ord_lst, left_to_trade
    # OR 
    # returns Tuple with 2 elements - ord_lst, funds_leftover
    return trade
end

function cancelLimitOrderSale(order::CancelOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    canceled_order = VL_LimitOrderBook.cancel_order!(eval(ob_expr),order.order_id,SELL_ORDER,order.limit_price)
    # returns `popped order` (ord::Union{Order{Sz,Px,Oid,Aid},Nothing}), is nothing if no order found
    return canceled_order
end

function cancelLimitOrderPurchase(order::CancelOrder)
    ticker_ob = order.ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    canceled_order = VL_LimitOrderBook.cancel_order!(eval(ob_expr),order.order_id,BUY_ORDER,order.limit_price)
    # returns `popped order` (ord::Union{Order{Sz,Px,Oid,Aid},Nothing}), is nothing if no order found
    return canceled_order
end

# ======================================================================================== #
#----- Quote Services -----#

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
    
end # module