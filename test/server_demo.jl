using Brokerage, Dates

const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/portfolios_demo.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")

server = @async Brokerage.run(DBFILE, AUTHFILE)
    
# show message to user -
# host_ip_address = Sockets.getipaddr()
# start_message = "Server started. address: $(host_ip_address) port: $(port_number) at $(now())";
start_message = "Server started. address: 0.0.0.0 port: 8080 at $(Dates.now(Dates.UTC))";
@info start_message

# include("test/server_demo.jl")