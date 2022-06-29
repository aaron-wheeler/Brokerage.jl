using Test, Brokerage

# to init with a new database -> "../test/newdbname.sqlite" 
const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/Nportfolios.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")

server = @async Brokerage.run(DBFILE, AUTHFILE)

Client.createUser("aaron", "password123")
user = Client.loginUser("aaron", "password123")

por1 = Client.createPortfolio("Trader 1", 10500, [1, 2])

# @testset "Test 1" begin
#     @test Client.pickRandomPortfolio() == por1
#     @test Client.pickRandomPortfolio() == por1
#     @test Client.getPortfolio(por1.id) == por1
# end

# push!(por1.holdings, 3)
# por2 = Client.updatePortfolio(por1)

# @testset "Test 2" begin
#     @test length(por2.holdings) == 3
#     @test length(Client.getPortfolio(por1.id).holdings) == 3
# end

# Client.deletePortfolio(por1.id)
# por2 = Client.createPortfolio("Trader 2", 9670, [2, 4])
# @test Client.pickRandomPortfolio() == por2

# Client.createUser("aaronW", "password456")
# user = Client.loginUser("aaronW", "password456")

# por1 = Client.createPortfolio("Trader 3", 10500, [1, 2])