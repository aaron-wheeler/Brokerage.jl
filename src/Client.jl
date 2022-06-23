module Client

using HTTP, JSON3, Base64
using ..Model

# server running on same host as client, listening on port 8080
# Ref String so that we can easily change this later, Client.SERVER[] = "http://www.newaddress.com"
const SERVER = Ref{String}("http://localhost:8080")

# cookies handled this way becuase of google cloud run wiping them in their service
function createUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

function loginUser(username, password)
    body = (; username, password=base64encode(password))
    resp = HTTP.post(string(SERVER[], "/user/login"), [], JSON3.write(body))
    return JSON3.read(resp.body, User)
end

# the following functions mirror what was written in the Resource module
# cookies handled this way becuase of google cloud run wiping them in their service
function createAlbum(name, artist, year, songs)
    body = (; name, artist, year, songs) # JSON3 will serialize this named tuple into a json object for the Resource create album function 
    resp = HTTP.post(string(SERVER[], "/album"), [], JSON3.write(body))
    return JSON3.read(resp.body, Album)
end

function getAlbum(id)
    resp = HTTP.get(string(SERVER[], "/album/$id"))
    return JSON3.read(resp.body, Album)
end

function updateAlbum(album)
    resp = HTTP.put(string(SERVER[], "/album/$(album.id)"), [], JSON3.write(album))
    return JSON3.read(resp.body, Album)
end

function deleteAlbum(id)
    resp = HTTP.delete(string(SERVER[], "/album/$id"))
    return
end

function pickAlbumToListen()
    resp = HTTP.get(string(SERVER[], "/"))
    return JSON3.read(resp.body, Album)
end

end # module