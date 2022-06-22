using Test, Brokerage

const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/albums.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")

server = @async Brokerage.run(DBFILE, AUTHFILE)

# using HTTP; HTTP.CookieRequest.default_cookiejar[1]

Client.createUser("aaron", "password!")
user = Client.loginUser("aaron", "password!")

# @testset "Test 1" begin
#     @test Client.pickAlbumToListen() == alb1
#     # @test Client.pickAlbumToListen() == alb1
    
#     @test Client.getAlbum(alb1.id) == alb1
# end

# @testset "Test 2" begin
#     push!(alb1.songs, "Shame, Shame, Shame")
#     alb2 = Client.updateAlbum(alb1)
#     @test length(alb2.songs) == 3
#     @test length(Client.getAlbum(alb1.id).songs) == 3
#     Client.deleteAlbum(alb1.id)
# end