using Brokerage
using Test

@testset "Test 1" begin
    @test example(2,1) == 5
end

@testset "Test 2" begin
    @test example(3,1) == 7
end