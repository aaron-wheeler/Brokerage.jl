module Model

import Base: ==

# StructTypes is used by JSON3 to do all of our object serialization
using StructTypes

export Portfolio, User

# Brokerage uses 'id' to distinguish between multiple portfolios
# Brokerage uses 'userid' to connect a Client to a portfolio
# Clients can use 'name' to connect a Trader/Agent to a portfolio
# Brokerage uses a universal designated INTEGER id for assets in 'holdings'
mutable struct Portfolio
    id::Int64 # service-managed
    userid::Int64 # service-managed
    name::String # passed by client
    cash::Int64 # passed by client, TODO: make this BigInt
    timespicked::Int64 # service-managed
    holdings::Vector{Int64} # TODO: avoid making this 64-bit
end

# default constructors for JSON3
==(x::Portfolio, y::Portfolio) = x.id == y.id
Portfolio() = Portfolio(0, 0, "", 0, 0, Int[])
Portfolio(name, cash, holdings) = Portfolio(0, 0, name, cash, 0, holdings)
StructTypes.StructType(::Type{Portfolio}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{Portfolio}) = :id # for 'get' function in Mapper

mutable struct User
    id::Int64 # service-managed
    username::String
    password::String
end

==(x::User, y::User) = x.id == y.id
User() = User(0, "", "")
User(username::String, password::String) = User(0, username, password)
User(id::Int64, username::String) = User(id, username, "")
StructTypes.StructType(::Type{User}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{User}) = :id

end # module