using Test, Brokerage

const DBFILE = joinpath(dirname(pathof(Brokerage)), "../test/albums.sqlite")
const AUTHFILE = "file://" * joinpath(dirname(pathof(Brokerage)), "../resources/authkeys.json")

server = @async Brokerage.run(DBFILE, AUTHFILE)

Client.createUser("aaron", "password!")
user = Client.loginUser("aaron", "password!")

alb1 = Client.createAlbum("Free Yourself Up", "Lake Street Dive", 2018, ["Baby Don't Leave Me Alone With My Thoughts", "Good Kisser"])

@testset "Test 1" begin
    @test Client.pickAlbumToListen() == alb1
    @test Client.pickAlbumToListen() == alb1
    @test Client.getAlbum(alb1.id) == alb1
end

push!(alb1.songs, "Shame, Shame, Shame")
alb2 = Client.updateAlbum(alb1)

@testset "Test 2" begin
    @test length(alb2.songs) == 3
    @test length(Client.getAlbum(alb1.id).songs) == 3
end

Client.deleteAlbum(alb1.id)
alb2 = Client.createAlbum("Haunted Heart", "Charlie Haden Quartet West", 1991, ["Introduction", "Hello My Lovely"])
@test Client.pickAlbumToListen() == alb2