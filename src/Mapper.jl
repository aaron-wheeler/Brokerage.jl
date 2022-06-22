module Mapper
# storage layer for passing model objects into

using ..Model, ..Contexts, ..ConnectionPools
using SQLite, DBInterface, Strapping, Tables

# pod is a specific key to a pool of SQLite database connections
const DB_POOL = Ref{ConnectionPools.Pod{ConnectionPools.Connection{SQLite.DB}}}()
const COUNTER = Ref{Int64}(0)

# define the relational database (denormalized here - simplified "one album (aka row) per song")
# check normalized.jl for normalized database where we properly store songs Vector as seperate tables
# we use these database connections to store the objects we defined in Model.jl
# database config options in 2nd line of function:
# (num of concurrent requests we allow (nthreads here), how long they last for in our connections (60 sec here), ..)
# the additional execute methods create indices on the columns we'll be filtering on (helps with speed)
function init(dbfile)
    new = () -> SQLite.DB(dbfile)
    DB_POOL[] = ConnectionPools.Pod(SQLite.DB, Threads.nthreads(), 60, 1000, new)
    if !isfile(dbfile)
        db = SQLite.DB(dbfile)
        DBInterface.execute(db, """
            CREATE TABLE album (
                id INTEGER,
                userid INTEGER,
                name TEXT,
                artist TEXT,
                year INTEGER,
                timespicked INTEGER DEFAULT 0,
                songs TEXT
            )
        """)
        DBInterface.execute(db, """
            CREATE INDEX idx_album_id ON album (id)
        """)
        DBInterface.execute(db, """
            CREATE INDEX idx_album_userid ON album (userid)
        """)
        DBInterface.execute(db, """
            CREATE INDEX idx_album_id_userid ON album (id, userid)
        """)
        DBInterface.execute(db, """
            CREATE TABLE user (
                id INTEGER PRIMARY KEY,
                username TEXT,
                password TEXT
            )
        """)
    end
    return
end

# withconnection uses thread safe connection pool to pass "db" database connection
# returns result of DBInterface.execute function and releases connection back to pool
function execute(sql, params; executemany::Bool=false)
    withconnection(DB_POOL[]) do db
        stmt = DBInterface.prepare(db, sql)
        println("Statement = ", stmt)
        if executemany
            DBInterface.executemany(stmt, params)
        else
            DBInterface.execute(stmt, params)
        end
    end
end

# inserting as many rows as there are albums
# `?` here are parameters which are filled iteratively
# deconstructing julia object into column iterables, which DBInterface uses to make many tables
function insert(album)
    user = Contexts.getuser()
    album.userid = user.id
    execute("""
        INSERT INTO album (id, userid, name, artist, year, timespicked, songs) VALUES(?, ?, ?, ?, ?, ?, ?)
    """, columntable(Strapping.deconstruct(album)); executemany=true)
    return
end

function create!(album::Album)
    album.id = COUNTER[] += 1
    insert(album)
    return
end

function update(album)
    delete(album.id)
    insert(album)
    return
end

function get(id)
    user = Contexts.getuser()
    cursor = execute("SELECT * FROM album WHERE id = ? AND userid = ?", (id, user.id))
    return Strapping.construct(Album, cursor)
end

function delete(id)
    user = Contexts.getuser()
    execute("DELETE FROM album WHERE id = ? AND userid = ?", (id, user.id))
    return
end

function getAllAlbums()
    user = Contexts.getuser()
    cursor = execute("SELECT * FROM album WHERE userid = ?", (user.id,))
    return Strapping.construct(Vector{Album}, cursor)
end

function create!(user::User)
    x = execute("""
        INSERT INTO user (username, password) VALUES (?, ?)
    """, (user.username, user.password))
    user.id = DBInterface.lastrowid(x)
    return
end

# uses struct idproperty in Model.jl to do this
function get(user::User)
    cursor = execute("SELECT * FROM user WHERE username = ?", (user.username,))
    println("cursor = ", cursor)
    return Strapping.construct(User, cursor)
end

end # module