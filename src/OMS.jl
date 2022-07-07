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


# submit_market_order!(ob::OrderBook,side::OrderSide,mo_size[,fill_mode::OrderTraits])
# submit_market_order_byfunds!(ob::OrderBook,side::Symbol,funds[,mode::OrderTraits])

# cancel_order!(ob,orderid,side,price)

# ======================================================================================== #

# best_bid_ask(ob) # returns tuple of best bid and ask prices in the order book
# book_depth_info(ob) # nested dict of prices, volumes and order counts at a specified max_depth (default = 5)
# get_acct(ob,acct_id) # return all open orders assigned to account `acct_id`
# volume_bid_ask(ob)
# n_orders_bid_ask(ob)
    
end # module