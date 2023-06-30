module Brokerage

export Model, Mapper, OMS, Service, Resource, Client

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

function run(dbfile, authkeysfile)
    # Workers.init()
    Mapper.init(dbfile)
    Auth.init(authkeysfile)
    Resource.run()
end

function remote_run(dbfile, authkeysfile)
    # Workers.init()
    Mapper.init(dbfile)
    Auth.init(authkeysfile)
    Resource.remote_run()
end

end
