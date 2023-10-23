module Brokerage

# export microservice layers
export Model, Mapper, OMS, Service, Resource, Client

# load packages
include("ConnectionPools.jl")
using .ConnectionPools

include("Model.jl")
using .Model

include("Auth.jl")
using .Auth

include("Contexts.jl")
using .Contexts

include("Mapper.jl")
using .Mapper

include("OMS.jl")
using .OMS

include("Service.jl")
using .Service

include("Resource.jl")
using .Resource

include("Client.jl")
using .Client

# initialize server locally; used for testing and debugging
function run(dbfile, authkeysfile)
    Mapper.init(dbfile)
    Auth.init(authkeysfile)
    Resource.run()
end

# initialize server remotely; used for deployment
function remote_run(dbfile, authkeysfile)
    Mapper.init(dbfile)
    Auth.init(authkeysfile)
    Resource.remote_run()
end

end
