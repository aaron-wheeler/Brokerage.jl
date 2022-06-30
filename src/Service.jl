module Service
# perform the services defined in the Resource layer and validate inputs

using Dates, ExpiringCaches
using ..Model, ..Mapper, ..Auth
# using ..Model, ..NormalizedMapper, ..Auth

function createPortfolio(obj)
    @assert haskey(obj, :name) && !isempty(obj.name)
    @assert haskey(obj, :holdings) && !isempty(obj.holdings)
    @assert haskey(obj, :cash) && 1 < obj.cash < 1000000
    portfolio = Portfolio(obj.name, obj.cash, obj.holdings)
    Mapper.create!(portfolio)
    # NormalizedMapper.create!(portfolio)
    return portfolio
end

@cacheable Dates.Hour(1) function getPortfolio(id::Int64)::Portfolio
    Mapper.get(id)
    # NormalizedMapper.get(id)
end

# consistent with model struct, not letting client define their own id, we manage these as a service
function updatePortfolio(id, updated)
    portfolio = Mapper.get(id)
    # portfolio = NormalizedMapper.get(id)
    portfolio.name = updated.name
    portfolio.cash = updated.cash
    portfolio.holdings = updated.holdings
    Mapper.update(portfolio)
    # NormalizedMapper.update(portfolio)
    delete!(ExpiringCaches.getcache(getPortfolio), (id,))
    return portfolio
end

function deletePortfolio(id)
    Mapper.delete(id)
    # NormalizedMapper.delete(id)
    delete!(ExpiringCaches.getcache(getPortfolio), (id,))
    return
end

function pickRandomPortfolio()
    portfolios = Mapper.getAllPortfolios()
    # portfolios = NormalizedMapper.getAllPortfolios()
    leastTimesPicked = minimum(x->x.timespicked, portfolios)
    leastPickedPortfolio = filter(x->x.timespicked == leastTimesPicked, portfolios)
    pickedPortfolio = rand(leastPickedPortfolio)
    pickedPortfolio.timespicked += 1
    Mapper.update(pickedPortfolio)
    # NormalizedMapper.update(pickedPortfolio)
    delete!(ExpiringCaches.getcache(getPortfolio), (pickedPortfolio.id,))
    @info "picked portfolio = $(pickedPortfolio.name) on thread = $(Threads.threadid())"
    return pickedPortfolio
end

# creates User struct defined in Model.jl
function createUser(user)
    @assert haskey(user, :username) && !isempty(user.username)
    @assert haskey(user, :password) && !isempty(user.password)
    user = User(user.username, user.password)
    Mapper.create!(user)
    # NormalizedMapper.create!(user)
    return user
end

# done this way so that we can persist user
function loginUser(user)
    persistedUser = Mapper.get(user)
    # persistedUser = NormalizedMapper.get(user)
    if persistedUser.password == user.password
        persistedUser.password = ""
        return persistedUser
    else
        println("persistedUser Login Error: User not recognized")
        throw(Auth.Unauthenticated())
    end
end

end # module