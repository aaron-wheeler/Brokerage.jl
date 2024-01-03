using Test, Dates, Brokerage

# init database; to init with a new database -> "../test/new_db_name.sqlite" 
const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolios.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")
Mapper.MM_COUNTER[] = 30 # number of accounts reserved for market makers

# init LOB
OMS.NUM_ASSETS[] = 2 # number of assets
OMS.PRICE_BUFFER_CAPACITY[] = 100 # number of price points to store
OMS.MARKET_OPEN_T[] = Dates.now() + Dates.Minute(1) # market open time
OMS.MARKET_CLOSE_T[] = OMS.MARKET_OPEN_T[] + Dates.Minute(10) # market close time
OMS.init_LOB!(OMS.ob, OMS.LP_order_vol, OMS.LP_cancel_vol, OMS.trade_volume_t, OMS.price_buffer)

# init server
server = @async Brokerage.run(DBFILE, AUTHFILE)

# init user
Client.createUser("aaron", "password123")
user = Client.loginUser("aaron", "password123")

# init trader
por1 = Client.createPortfolio("Trader 1", 10500.0, Dict(1 => 10, 2 => 12))
holdings1 = Client.getHoldings(por1)
cash1 = Client.getCash(por1)

## Trade update testing
# Trade ex. 1: limit order sell - market order buy
ord1 = Client.placeLimitOrder(1,"SELL_ORDER",99.0,7,por1)
por2 = Client.createPortfolio("Trader 2", 9000.0, Dict(1 => 15, 2 => 5)) # new trader
ord2 = Client.placeMarketOrder(1,"BUY_ORDER",5,por2)
holdings2 = Client.getHoldings(por2)

@testset "Limit Order Tests" begin
    @test holdings2[:1] == 20
    cash1 = Client.getCash(por1)
    @test cash1 == 10500.0 + (5 * 99.0)
    cash2 = Client.getCash(por2)
    @test cash2 == 9000.0 - (5 * 99.0)
end

# Trade ex. 2: cancel rest of unmatched limit order (trader 1)
@test Client.getHoldings(por1)[:1] == 3
active_orders = Client.getActiveOrders(por1, 1)
order_id = first(active_orders)[1]
Client.placeCancelOrder(1,order_id,"SELL_ORDER",99.0,por1)

@testset "Unmatched Order Consistency" begin
    @test Client.getHoldings(por1)[:1] == 5
    @test Client.getBidAsk(1)[2] != 99.0 
end

# Trade ex. 3: limit order buy - market order sell
ord3 = Client.placeLimitOrder(1,"BUY_ORDER",99.0,10,por1)
ord4 = Client.placeMarketOrder(1,"SELL_ORDER",10,por2)

@testset "Matching Order Types" begin
    @test Client.getHoldings(por1)[:1] == 15
    @test Client.getHoldings(por2)[:1] == 10
    @test Client.getCash(por1) == 10500.0 + (5 * 99.0) - (10 * 99.0)
    @test Client.getCash(por2) == 9000.0 - (5 * 99.0) + (10 * 99.0) 
end

# Trade ex. 4: market orders by funds
ord5 = Client.placeLimitOrder(1,"SELL_ORDER",99.0,3,por2)
funds1 = 99.0 * 3 # for trader 1 to partially clear trader 2's buy LO
ord6 = Client.placeMarketOrder(1,"BUY_ORDER",funds1,por1,byfunds = true)

@testset "Market Order Via Funds 1" begin
    # @test Client.getHoldings(por1)[:1] == 15 - 3 - 3
    @test Client.getHoldings(por1)[:1] == 15 + 3
    @test Client.getHoldings(por2)[:1] == 10 - 3
    @test Client.getCash(por1) == 10500.0 + (5 * 99.0) - (10 * 99.0) - funds1
    @test Client.getCash(por2) == 9000.0 - (5 * 99.0) + (10 * 99.0) + (3 * 99.0)
end
ord7 = Client.placeLimitOrder(1,"BUY_ORDER",99.0,4,por1)
funds2 = 99.0 * 3 # for trader 2 to partially clear trader 1's sell LO
ord8 = Client.placeMarketOrder(1,"SELL_ORDER",funds2,por2,byfunds = true)

@testset "Market Order Via Funds 2" begin
    @test Client.getCash(por2) == 9000.0 - (5 * 99.0) + (10 * 99.0) + (3 * 99.0) + funds2
    @test Client.getCash(por1) == 10500.0 + (5 * 99.0) - (10 * 99.0) - funds1 - funds2 - (1 * 99.0)
    @test Client.getHoldings(por2)[:1] == 10 - 3 - 3
    @test Client.getHoldings(por1)[:1] == 15 + 3 + 3 
end

# Trade ex. 5: cancel order consistency
@test Client.getBidAsk(1)[1] == 99.0
active_orders = Client.getActiveOrders(por1, 1)
order_id = first(active_orders)[1]
Client.placeCancelOrder(1,order_id,"BUY_ORDER",99.0,por1)

@testset "Cancel Order Consistency" begin
    @test Client.getCash(por1) == 10500.0 + (5 * 99.0) - (10 * 99.0) - funds1 - funds2
    @test Client.getBidAsk(1)[2] != 99.0
    @test isempty(Client.getActiveOrders(por1, 1))
    # trader 1 order completed, test for exception
    # @test_throws Brokerage.Service.OrderNotFound Client.placeCancelOrder(1,54,"SELL_ORDER",99.0,por1) # error works but testing for it is tricky over HTTP
end

## Quote testing
mid_price = Client.getMidPrice(1)
bid, ask = Client.getBidAsk(1)
depth = Client.getBookDepth(1)
book_volume = Client.getBidAskVolume(1)
n_orders_book = Client.getBidAskOrders(1) 

## Multi-asset testing
ord9 = Client.placeMarketOrder(2,"SELL_ORDER",1,por1)
ord10 = Client.placeMarketOrder(2,"BUY_ORDER",3,por1)

## Price history testing
price_history_1 = Client.getPriceSeries(1)
@test Client.getPriceSeries(1) == [99.0, 99.0, 99.0, 99.0]

## Market schedule testing
market_open, market_close = Client.getMarketSchedule()
@test market_open < market_close

## Market Maker testing
MM_id = 1
Client.provideLiquidity(1,"SELL_ORDER",99.0,7,MM_id)
active_orders = Client.getActiveOrders(MM_id, 1)
active_sell_orders = Client.getActiveSellOrders(MM_id, 1)
active_buy_orders = Client.getActiveBuyOrders(MM_id, 1)
@test isempty(active_sell_orders) == false
@test isempty(active_buy_orders) == true
ask_volume_t1 = Client.getBidAskVolume(1)[2]
Client.hedgeTrade(1,"BUY_ORDER",100,MM_id)
ask_volume_t2 = Client.getBidAskVolume(1)[2]
ask_vol_diff = ask_volume_t1 - ask_volume_t2
@test ask_vol_diff == 100
@test OMS.trade_volume_t[1] == 121
@test OMS.trade_volume_t[1] == Client.getTradeVolume(1)

## Fractional share testing
# ord11 = Client.placeLimitOrder(1,"SELL_ORDER",99.0,1.7,por1)
# ord12 = Client.placeMarketOrder(1,"BUY_ORDER",1.1,por1)
# ord13 = Client.placeMarketOrder(1,"SELL_ORDER",0.09,por1)

## Data collection testing
# OMS.write_market_data(OMS.ticker_symbol, OMS.tick_time, OMS.tick_bid_prices,
#             OMS.tick_ask_prices, OMS.tick_last_prices, OMS.tick_trading_volume)
# OMS.write_LP_data(OMS.LP_order_vol, OMS.LP_cancel_vol)