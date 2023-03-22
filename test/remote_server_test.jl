using Brokerage, Dates, Sockets

const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolio.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")
OMS.NUM_ASSETS[] = 1
OMS.PRICE_BUFFER_CAPACITY[] = 100
OMS.init_LOB!(OMS.ob, OMS.LP_order_vol, OMS.LP_cancel_vol, OMS.trade_volume_t, OMS.price_buffer)

server = @async Brokerage.remote_run(DBFILE, AUTHFILE)
    
# show message to user -
port_number = 8080
host_ip_address = Sockets.getipaddr()
@info "Server started. address: $(host_ip_address) port: $(port_number) at $(Dates.now(Dates.UTC))"

# include("test/remote_server_test.jl")