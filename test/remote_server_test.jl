using Brokerage, Dates, Sockets

const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolio.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")
Mapper.MM_COUNTER[] = 30
init_price = [99.0, 82.0]
OMS.NUM_ASSETS[] = length(init_price)
OMS.PRICE_BUFFER_CAPACITY[] = 100
OMS.MARKET_OPEN_T[] = Dates.now() + Dates.Minute(1) # DateTime(2022,7,19,13,19,41,036)
OMS.MARKET_CLOSE_T[] = OMS.MARKET_OPEN_T[] + Dates.Minute(10)
# OMS.init_LOB!(OMS.ob, OMS.LP_order_vol, OMS.LP_cancel_vol, OMS.trade_volume_t, OMS.price_buffer)
OMS.init_LOB!(OMS.ob, init_price, OMS.LP_order_vol, OMS.LP_cancel_vol, OMS.trade_volume_t, OMS.price_buffer)

server = @async Brokerage.remote_run(DBFILE, AUTHFILE)
    
# show message to user -
port_number = 8080
host_ip_address = Sockets.getipaddr()
@info "Server started. address: $(host_ip_address) port: $(port_number) at $(Dates.now(Dates.UTC))"

# include("test/remote_server_test.jl")