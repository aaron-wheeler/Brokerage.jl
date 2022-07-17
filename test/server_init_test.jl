using Test, Brokerage

# to init with a new database -> "../test/newdbname.sqlite" 
const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolios.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")

server = @async Brokerage.run(DBFILE, AUTHFILE)

## do the following in a seperate client terminal

Client.createUser("aaron", "password123")
user = Client.loginUser("aaron", "password123")

por1 = Client.createPortfolio("Trader 1", 10500.0, Dict(1 => 10.0, 2 => 12.5))
holdings1 = Client.getHoldings(por1)
cash1 = Client.getCash(por1)

## Order testing
ord1 = Client.placeLimitOrder(1,12,"SELL_ORDER",99.0,7,por1)
holdings1 = Client.getHoldings(por1)
@test holdings1[:1] == 3
bid, ask = Client.getBidAsk(1)
@test ask == 99.0
# crossed order
ord2 = Client.placeLimitOrder(1,87,"BUY_ORDER",100.0,7,por1)
@test Client.getBidAsk(1)[2] != 99.0
holdings1 = Client.getHoldings(por1)
@test holdings1[:1] == 10

# # OMS.ob1 # changed order book can only be seen on server side terminal ** (haven't incorporated qoute service yet)

## Trade update testing
# Trade ex. 1: limit order sell - market order buy
ord3 = Client.placeLimitOrder(1,11,"SELL_ORDER",99.0,7,por1)
# new trader
por2 = Client.createPortfolio("Trader 2", 9000.0, Dict(1 => 15.0, 2 => 5.0))
ord4 = Client.placeMarketOrder(1,81,"BUY_ORDER",5,por2)
holdings2 = Client.getHoldings(por2)
@test holdings2[:1] == 20
cash1 = Client.getCash(por1)
@test cash1 == 10500.0 + (5 * 99.0)
cash2 = Client.getCash(por2)
@test cash2 == 9000.0 - (5 * 99.0)

# Trade ex. 2: cancel rest of unmatched limit order (trader 1)
@test Client.getHoldings(por1)[:1] == 3
Client.placeCancelOrder(1,11,"SELL_ORDER",99.0,por1)
@test Client.getHoldings(por1)[:1] == 5
@test Client.getBidAsk(1)[2] != 99.0

# Trade ex. 3: limit order buy - market order sell
ord5 = Client.placeLimitOrder(1,83,"BUY_ORDER",98.99,10,por1)
ord6 = Client.placeMarketOrder(1,28,"SELL_ORDER",10,por2)
@test Client.getHoldings(por1)[:1] == 15
@test Client.getHoldings(por2)[:1] == 10
@test Client.getCash(por1) == 10500.0 + (5 * 99.0) - (10 * 98.99)
@test Client.getCash(por2) == 9000.0 - (5 * 99.0) + (10 * 98.99)

# Trade ex. 4: market orders by funds
ord7 = Client.placeLimitOrder(1,54,"SELL_ORDER",99.0,3,por1)
ord8 = Client.placeLimitOrder(1,55,"BUY_ORDER",98.99,4,por2)
funds1 = 98.99 * 3 # for trader 1 to partially clear trader 2's buy LO
funds2 = 99.0 * 3 # for trader 2 to clear trader 1's sell LO
ord9 = Client.placeMarketOrder(1,32,"SELL_ORDER",funds1,por1,byfunds = true)
@test Client.getHoldings(por1)[:1] == 15 - 3 - 3
@test Client.getHoldings(por2)[:1] == 10 + 3
@test Client.getCash(por1) == 10500.0 + (5 * 99.0) - (10 * 98.99) + funds1
@test Client.getCash(por2) == 9000.0 - (5 * 99.0) + (10 * 98.99) - (4 * 98.99)
ord10 = Client.placeMarketOrder(1,21,"BUY_ORDER",funds2,por2,byfunds = true)
@test Client.getCash(por2) == 9000.0 - (5 * 99.0) + (10 * 98.99) - (4 * 98.99) - funds2
@test Client.getCash(por1) == 10500.0 + (5 * 99.0) - (10 * 98.99) + funds1 + funds2
@test Client.getHoldings(por2)[:1] == 10 + 3 + 3
@test Client.getHoldings(por1)[:1] == 15 - 3 - 3

# Trade ex. 5: cancel order consistency
@test Client.getBidAsk(1)[1] == 98.99
Client.placeCancelOrder(1,55,"BUY_ORDER",98.99,por2)
@test Client.getCash(por2) == 9000.0 - (5 * 99.0) + (10 * 98.99) - (4 * 98.99) - funds2 + (1 * 98.99)
@test Client.getBidAsk(1)[1] != 98.99
# trader 1 order completed, test for exception
# @test_throws Brokerage.Service.OrderNotFound Client.placeCancelOrder(1,54,"SELL_ORDER",99.0,por1) # error works but testing for it is tricky over HTTP

## Quote testing
mid_price = Client.getMidPrice(1)
bid, ask = Client.getBidAsk(1)
depth = Client.getBookDepth(1)
book_volume = Client.getBidAskVolume(1)
n_orders_book = Client.getBidAskOrders(1)

## Multi-asset testing
ord11 = Client.placeMarketOrder(2,24,"SELL_ORDER",1,por1)
ord12 = Client.placeMarketOrder(2,29,"BUY_ORDER",3,por1)

## Fractional share testing
# ord13 = Client.placeLimitOrder(1,87,"SELL_ORDER",99.0,1.7,por1) # TODO: fix OrderInsertionError
ord14 = Client.placeMarketOrder(1,81,"BUY_ORDER",1.1,por1)
ord15 = Client.placeMarketOrder(1,81,"SELL_ORDER",0.09,por1)

# @testset "Test 1" begin
#     @test Client.pickRandomPortfolio() == por1
#     @test Client.pickRandomPortfolio() == por1
#     @test Client.getPortfolio(por1) == por1
# end

# push!(por1.holdings, 3)
# por2 = Client.updatePortfolio(por1)

# @testset "Test 2" begin
#     @test length(por2.holdings) == 3
#     @test length(Client.getPortfolio(por1).holdings) == 3
# end

# Client.deletePortfolio(por1)
# por2 = Client.createPortfolio("Trader 2", 9670.0, [2, 4])
# @test Client.pickRandomPortfolio() == por2

# Client.createUser("aaronW", "password456")
# user = Client.loginUser("aaronW", "password456")

# newuser_por1 = Client.createPortfolio("Trader 3", 10500.80, [1, 2, 3, 4])

# For trouble-shooting VL_LimitOrderBook integration...
# using VL_LimitOrderBook
# order = Model.LimitOrder(1,101, "SELL_ORDER", 99.10, 5, 1287)
# Service.processTrade(order)
# order = Model.LimitOrder(1,101, "BUY_ORDER", 99.10, 5, 1287)
# Service.processTrade(order)
# VL_LimitOrderBook notify functionality needs to be revisted, the above order does not appear to match and notify