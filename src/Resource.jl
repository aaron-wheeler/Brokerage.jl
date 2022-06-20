module Resource
# this module defines server-side stuff

using Dates, HTTP, JSON3
# .. means use this package as defined in the top level scope (as opposed to include())
using ..Model, ..Service, ..Auth, ..Contexts, ..Workers

const ROUTER = HTTP.Router()

# the createAlbum function will pass a request `req` from the client, into the service layer
# JSON3 will translate the http message into json and parse the request message body for the service layer
createAlbum(req) = Service.createAlbum(JSON3.read(req.body))::Album # requestHandler function
HTTP.@register(ROUTER, "POST", "/album", createAlbum) # when the method is post, we call the above function

getAlbum(req) = Service.getAlbum(parse(Int, HTTP.URIs.splitpath(req.target)[2]))::Album
HTTP.@register(ROUTER, "GET", "/album/*", getAlbum) # asterick here means match anything after the '/'

# the album must be passed in by the client here 
updateAlbum(req) = Service.updateAlbum(parse(Int, HTTP.URIs.splitpath(req.target)[2]), JSON3.read(req.body, Album))::Album
HTTP.@register(ROUTER, "PUT", "/album/*", updateAlbum) # PUT aka updating something here 

deleteAlbum(req) = Service.deleteAlbum(parse(Int, HTTP.URIs.splitpath(req.target)[2]))
HTTP.@register(ROUTER, "DELETE", "/album/*", deleteAlbum)

# nothing passed in by the client here, service layer does all the logic
# want this handled asynchronously in background threads and not thread 1
# Workers.jl - workers are assigned the pickAlbumToListen function, and then we fetch the result of that
# fetch is happening on thread 1 but is non-blocking, it will wait and task switch until 
# the background thread is done doing the work, it will return to thread 1 which does fast serialize/deserialize
pickAlbumToListen(req) = fetch(Workers.@async(Service.pickAlbumToListen()::Album))
HTTP.@register(ROUTER, "GET", "/", pickAlbumToListen)

# using Contexts.jl
# if User is valid (authenticated) then this will work and use can use original requestHandler functions 
function contextHandler(req)
    withcontext(User(req)) do
        HTTP.Response(200, JSON3.write(HTTP.handle(ROUTER, req)))
    end
end

# leveraging the authentication middleware
const AUTH_ROUTER = HTTP.Router(contextHandler)

function authenticate(user::User)
    resp = HTTP.Response(200, JSON3.write(user))
    return Auth.addtoken!(resp, user)
end

createUser(req) = authenticate(Service.createUser(JSON3.read(req.body))::User)
HTTP.@register(AUTH_ROUTER, "POST", "/user", createUser)

loginUser(req) = authenticate(Service.loginUser(JSON3.read(req.body, User))::User)
HTTP.@register(AUTH_ROUTER, "POST", "/user/login", loginUser)

# HTTP RequestHandler middleware
# takes in request and routes it to the appropriate requestHandler function
# will need to adapt this to Http Streams -> streamHandler(req, resp)
function requestHandler(req)
    start = Dates.now(Dates.UTC)
    @info (timestamp=start, event="ServiceRequestBegin", tid=Threads.threadid(), method=req.method, target=req.target)
    local resp
    try
        resp = HTTP.handle(AUTH_ROUTER, req) # passing in RequestHandler (eventually change to StreamHandler?) and request
    catch e
        if e isa Auth.Unauthenticated
            resp = HTTP.Response(401)
        else
            s = IOBuffer()
            showerror(s, e, catch_backtrace(); backtrace=true)
            errormsg = String(resize!(s.data, s.size))
            @error errormsg
            resp = HTTP.Response(500, errormsg)
        end
    end
    stop = Dates.now(Dates.UTC)
    @info (timestamp=stop, event="ServiceRequestEnd", tid=Threads.threadid(), method=req.method, target=req.target, duration=Dates.value(stop - start), status=resp.status, bodysize=length(resp.body))
    return resp
end

# for handling streams, add argument streams=true
function run()
    HTTP.serve(requestHandler, "0.0.0.0", 8080) # start up local server and listen to anyone from port 8080 from my machine
end

end # module