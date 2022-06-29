module Mapper
# storage layer for passing model objects into

using ..Model, ..Contexts, ..ConnectionPools
using SQLite, DBInterface, Strapping, Tables

# pod is a specific key to a pool of SQLite database connections
const DB_POOL = Ref{ConnectionPools.Pod{ConnectionPools.Connection{SQLite.DB}}}()
const COUNTER = Ref{Int64}(0)

# define the relational database (denormalized here - simplified "one portfolio (aka row) per song")
# check NormalizedMapper.jl for normalized database where we properly store holdings Vector as seperate tables
# we use these database connections to store the objects we defined in Model.jl
# database config options in 2nd line of function correspond to Pod Struct defined in ConnectionPools.jl
# the additional execute methods create indices on the columns we'll be filtering on (helps with speed)
function init(dbfile)
    new = () -> SQLite.DB(dbfile)
    DB_POOL[] = ConnectionPools.Pod(SQLite.DB, Threads.nthreads(), 60, 1000, new)
    if !isfile(dbfile)
        db = SQLite.DB(dbfile)
        DBInterface.execute(db, """
            CREATE TABLE portfolio (
                id INTEGER,
                userid INTEGER,
                name TEXT,
                cash INTEGER,
                timespicked INTEGER DEFAULT 0,
                holdings INTEGER
            )
        """)
        DBInterface.execute(db, """
            CREATE INDEX idx_portfolio_id ON portfolio (id)
        """)
        DBInterface.execute(db, """
            CREATE INDEX idx_portfolio_userid ON portfolio (userid)
        """)
        DBInterface.execute(db, """
            CREATE INDEX idx_portfolio_id_userid ON portfolio (id, userid)
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
        if executemany
            DBInterface.executemany(stmt, params)
        else
            DBInterface.execute(stmt, params)
        end
    end
end

# inserting as many rows as there are portfolios
# `?` here are parameters which are filled iteratively
# deconstructing julia object into column iterables, which DBInterface uses to make many tables
function insert(portfolio)
    user = Contexts.getuser()
    portfolio.userid = user.id
    execute("""
        INSERT INTO portfolio (id, userid, name, cash, timespicked, holdings) VALUES(?, ?, ?, ?, ?, ?)
    """, columntable(Strapping.deconstruct(portfolio)); executemany=true)
    return
end

function create!(portfolio::Portfolio)
    portfolio.id = COUNTER[] += 1
    insert(portfolio)
    return
end

function update(portfolio)
    delete(portfolio.id)
    insert(portfolio)
    return
end

function get(id)
    user = Contexts.getuser()
    cursor = execute("SELECT * FROM portfolio WHERE id = ? AND userid = ?", (id, user.id))
    return Strapping.construct(Portfolio, cursor)
end

function delete(id)
    user = Contexts.getuser()
    execute("DELETE FROM portfolio WHERE id = ? AND userid = ?", (id, user.id))
    return
end

function getAllPortfolios()
    user = Contexts.getuser()
    cursor = execute("SELECT * FROM portfolio WHERE userid = ?", (user.id,))
    return Strapping.construct(Vector{Portfolio}, cursor)
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
    return Strapping.construct(User, cursor)
end

end # module