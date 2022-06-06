using Brokerage
using Test

@testset "Brokerage.jl" begin
    @test Brokerage.example() == "Hello World!"
end
