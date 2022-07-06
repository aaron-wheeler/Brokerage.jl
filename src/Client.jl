module Client

using HTTP, JSON3, Base64
using ..Model

# server running on same host as client, listening on port 8080
# Ref String - we can easily change this later, Client.SERVER[] = "http://www.newaddress.com"
const SERVER = Ref{String}("http://localhost:8080")

# The following functions mirror what was written in the Resource module
# The functions calls are routed to the appropriate method via Resource.jl

# ======================================================================================== #

function createUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

function loginUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user/login"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

function createPortfolio(name, cash, holdings)
    body = (; name, cash, holdings) # JSON3 will serialize this named tuple into a json object for the Resource create portfolio function 
    resp = HTTP.post(string(SERVER[], "/portfolio"), [], JSON3.write(body))
    return JSON3.read(resp.body, Portfolio)
end

function getPortfolio(id)
    resp = HTTP.get(string(SERVER[], "/portfolio/$id"))
    return JSON3.read(resp.body, Portfolio)
end

function updatePortfolio(portfolio)
    resp = HTTP.put(string(SERVER[], "/portfolio/$(portfolio.id)"), [], JSON3.write(portfolio))
    return JSON3.read(resp.body, Portfolio)
end

function deletePortfolio(id)
    resp = HTTP.delete(string(SERVER[], "/portfolio/$id"))
    return
end

function pickRandomPortfolio()
    resp = HTTP.get(string(SERVER[], "/"))
    return JSON3.read(resp.body, Portfolio)
end

# ======================================================================================== #

function placeLimitOrder(ticker, order_id, order_side, limit_price, limit_size)
    body = (; ticker, order_id, order_side, limit_price, limit_size)
    resp = HTTP.post(string(SERVER[], "/order/$id"), [], JSON3.write(body))
    return JSON3.read(resp.body, LimitOrder)
end

end # module