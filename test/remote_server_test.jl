using Brokerage, Dates, Sockets

const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolio.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")
OMS.NUM_ASSETS[] = 3
OMS.init_LOB!(OMS.ob, OMS.uob, OMS.LP_order_vol, OMS.LP_cancel_vol)

server = @async Brokerage.remote_run(DBFILE, AUTHFILE)
    
# show message to user -
port_number = 8080
host_ip_address = Sockets.getipaddr()
@info "Server started. address: $(host_ip_address) port: $(port_number) at $(Dates.now(Dates.UTC))"

# include("test/remote_server_test.jl")