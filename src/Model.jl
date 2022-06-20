module Model

import Base: ==

# StructTypes is used by JSON3 to do all of it's object serialization
using StructTypes

export Album, User

mutable struct Album
    id::Int64 # service-managed
    userid::Int64 # service-managed
    name::String # passed by client
    artist::String # passed by client
    year::Int64 # passed by client
    timespicked::Int64 # service-managed
    songs::Vector{String}
end

# default constructors for JSON3
==(x::Album, y::Album) = x.id == y.id
Album() = Album(0, 0, "", "", 0, 0, String[])
Album(name, artist, year, songs) = Album(0, 0, name, artist, year, 0, songs)
StructTypes.StructType(::Type{Album}) = StructTypes.Mutable()
StructTypes.idproperty(::Type{Album}) = :id # for get function in Mapper

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