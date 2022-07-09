using VL_LimitOrderBook #, Random
using Dates
using Base.Iterators: zip,cycle,take,filter

# ======================================================================================== #
# BROKERAGE LOB INITIALIZATION
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

# order_info_lst = take(lmt_order_info_iter,12)
# # Add a bunch of orders
# for (orderid, price, size, side) in order_info_lst
#     submit_limit_order!(ob,uob,orderid,side,price,size,10101)
# end
# for (orderid, price, size, side) in order_info_lst
#     print(orderid, ' ',side,' ',price,'\n')
#     cancel_order!(ob,orderid,side,price)
# end

order_info_lst = take(lmt_order_info_iter,6)

# Add a bunch of orders
for (orderid, price, size, side) in order_info_lst
    submit_limit_order!(ob1,uob1,orderid,side,price,size,10101)
    print(orderid, ' ',side,' ',price,'\n')
end

# # Create second order book
# ob2 = MyLOBType() # Initialize empty order book
# uob2 = MyUOBType() # Initialize unmatched book process
# # fill book with random limit orders
# randspread() = ceil(-0.05*log(rand()),digits=2)
# rand_side() = rand([BUY_ORDER,SELL_ORDER])
# for i=1:10
#     # add some limit orders
#     submit_limit_order!(ob2,uob2,2i,BUY_ORDER,99.0-randspread(),rand(5:5:20),1287)
#     submit_limit_order!(ob2,uob2,3i,SELL_ORDER,99.0+randspread(),rand(5:5:20),1287)
#     if (rand() < 0.1) # and some market orders
#         submit_market_order!(ob2,rand_side(),rand(10:25:150))
#     end
# end

# ======================================================================================== #
# CLIENT ORDER MESSAGING 
# Order submission examples
#=
    Limit Order example

submit_limit_order!(
ob::OrderBook{Sz,Px,Oid,Aid},
uob::UnmatchedOrderBook{Sz,Px,Oid,Aid,Dt,Ip,Pt},
orderid::Oid,
side::OrderSide,
limit_price::Real,
limit_size::Real,
[, acct_id::Aid, fill_mode::OrderTraits ]
)
=#
ticker = 1
order_id = 10000
# order_side = "SELL_ORDER"
limit_price = 99.0
limit_size = 5
acct_id = 10101

function processLimitOrderSale(ticker, order_id, limit_price, limit_size)
    ticker_ob = ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    uob_expr = Symbol("uob"*"$ticker_ob")
    trade = VL_LimitOrderBook.submit_limit_order!(eval(ob_expr), eval(uob_expr), order_id,
                        SELL_ORDER, limit_price,
                        limit_size, acct_id)
    # returns Tuple with 3 elements - new_open_order, cross_match_lst, remaining_size
    return trade
end

function processLimitOrderPurchase(ticker, order_id, limit_price, limit_size)
    ticker_ob = ticker
    ob_expr = Symbol("ob"*"$ticker_ob")
    uob_expr = Symbol("uob"*"$ticker_ob")
    trade = VL_LimitOrderBook.submit_limit_order!(eval(ob_expr), eval(uob_expr), order_id,
                        BUY_ORDER, limit_price,
                        limit_size, acct_id)
    # returns Tuple with 3 elements - new_open_order, cross_match_lst, remaining_size
    return trade
end

trade = processLimitOrderSale(ticker, order_id, limit_price, limit_size)
trade = processLimitOrderPurchase(ticker, order_id, limit_price, limit_size)

# @test trade[1] == nothing # aka the order was matched completely
# @test trade[3] == 0 # aka the order was matched completely

# # sell order
# submit_limit_order!(ob1, uob1, my_order_id,
#                     SELL_ORDER, my_limit_order_s_price,
#                     my_limit_order_s_size, my_acct_id)
# # buy order
# my_limit_order_b_price = 100
# my_limit_order_b_size = 5
# submit_limit_order!(ob1, uob1, my_order_id,
#                     BUY_ORDER, my_limit_order_b_price,
#                     my_limit_order_b_size, my_acct_id)
# TODO - FIX: Right now this order isn't cleared from the active
# orders in get_acct() when matched--it still shows up

# submit_limit_order!(ob1,uob1,10000,SELL_ORDER,99.0,5,10101)
# submit_limit_order!(ob1,uob1,10000,BUY_ORDER,100,5,10101)

#=
    Market Order example

submit_market_order!(ob::OrderBook,side::OrderSide,mo_size[,fill_mode::OrderTraits])

additionally...
submit_market_order_byfunds!(ob::OrderBook,side::Symbol,funds[,mode::OrderTraits])

Functionality is exactly the same as submit_market_order! except available 
funds (max total price paid on order) is provided, rather than number of shares (order size).
=#
# market order
# submit_market_order!(ob1, BUY_ORDER, 5) # all 5 matched

# market order by funds
# submit_market_order_byfunds!(ob1, BUY_ORDER, 5.0) # if OrderSize::Int64, should match nothing and return back $5
# submit_market_order_byfunds!(ob1, BUY_ORDER, 100.0) # if OrderSize::Int64, should match 1 share and return back $0.9899978637695312

#=
    Cancel Order example

cancel_order!(ob,orderid,side,price)
=#
# submit_limit_order!(ob1, uob1, 111, SELL_ORDER, 99.009, 20, 101111)
# cancel_order!(ob1, 111, SELL_ORDER, 99.009)

# Additional functionality
# best_bid_ask(ob1) # returns tuple of best bid and ask prices in the order book
# book_depth_info(ob1) # nested dict of prices, volumes and order counts at a specified max_depth (default = 5)
# get_acct(ob1,acct_id) # return all open orders assigned to account `acct_id`
# volume_bid_ask(ob1)
# n_orders_bid_ask(ob1)

# include("test/server_LOB_test.jl")