module Mapper
# storage layer for passing model objects into

using ..Model, ..Contexts, ..ConnectionPools
using SQLite, DBInterface, Strapping, Tables

# pod is a specific key to a pool of SQLite database connections
const DB_POOL = Ref{ConnectionPools.Pod{ConnectionPools.Connection{SQLite.DB}}}()
const COUNTER = Ref{Int64}(0)

# define the normalized relational database where we store holdings Vector as seperate tables
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
                cash REAL,
                timespicked INTEGER DEFAULT 0
            )
        """)
        DBInterface.execute(db, """
            CREATE TABLE holdings (
                portfolio_id INTEGER,
                userid INTEGER,
                ticker INTEGER
            )
        """)
        # DBInterface.execute(db, """
        #     CREATE INDEX idx_holdings_portfolio_id_userid ON holdings (portfolio_id, userid)
        # """)
        # DBInterface.execute(db, """
        #     CREATE INDEX idx_portfolio_id ON holdings (portfolio_id)
        # """)
        DBInterface.execute(db, """
            CREATE TABLE pendingorders (
                portfolio_id INTEGER,
                userid INTEGER,
                transaction_id INTEGER DEFAULT 0
            )
        """)
        DBInterface.execute(db, """
            CREATE TABLE completedorders (
                portfolio_id INTEGER,
                userid INTEGER,
                transaction_id INTEGER DEFAULT 0
            )
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

function create!(portfolio::Portfolio)
    user = Contexts.getuser()
    portfolio.userid = user.id
    portfolio.id = COUNTER[] += 1
    execute("""
        INSERT INTO portfolio (id, userid, name, cash, timespicked) VALUES(?, ?, ?, ?, ?)
    """, (portfolio.id, portfolio.userid, portfolio.name, portfolio.cash, portfolio.timespicked))
    id = portfolio.id
    execute("""
        INSERT INTO holdings (portfolio_id, userid, ticker) VALUES (?, ?, ?)
    """, ([id for _ = 1:length(portfolio.holdings)], [user.id for _ = 1:length(portfolio.holdings)], portfolio.holdings); executemany=true)
    # implement pendingorders & completedorders as simple dummy vector for now
    execute("""
        INSERT INTO pendingorders (portfolio_id, userid, transaction_id) VALUES (?, ?, ?)
    """, ([id for _ = 1:length(portfolio.pendingorders)], [user.id for _ = 1:length(portfolio.pendingorders)], portfolio.pendingorders); executemany=true)
    execute("""
        INSERT INTO completedorders (portfolio_id, userid, transaction_id) VALUES (?, ?, ?)
    """, ([id for _ = 1:length(portfolio.completedorders)], [user.id for _ = 1:length(portfolio.completedorders)], portfolio.completedorders); executemany=true)
    return
end

function update(portfolio)
    user = Contexts.getuser()
    portfolio.userid = user.id
    execute("""
        UPDATE portfolio
        SET userid = ?,
            name = ?,
            cash = ?,
            timespicked = ?
        WHERE id = ?
    """, (portfolio.userid, portfolio.name, portfolio.cash, portfolio.timespicked, portfolio.id))
    # update holdings
    execute("""
        DELETE FROM holdings WHERE portfolio_id = ? AND userid = ?
    """, (portfolio.id, user.id))
    execute("""
        INSERT INTO holdings (portfolio_id, userid, ticker) VALUES (?, ?, ?)
    """, ([portfolio.id for _ = 1:length(portfolio.holdings)], [user.id for _ = 1:length(portfolio.holdings)], portfolio.holdings); executemany=true)
    # TODO: Implement logic for this 
    # update pendingorders
    # execute("""
    #     DELETE FROM pendingorders WHERE portfolio_id = ? AND userid = ?
    # """, (portfolio.id, user.id))
    # execute("""
    #     INSERT INTO pendingorders (portfolio_id, userid, transaction_id) VALUES (?, ?, ?)
    # """, ([portfolio.id for _ = 1:length(portfolio.pendingorders)], [user.id for _ = 1:length(portfolio.pendingorders)], portfolio.pendingorders); executemany=true)
    execute("""
        UPDATE pendingorders
        SET transaction_id = ?
        WHERE portfolio_id = ? AND userid = ?
    """, (portfolio.pendingorders, [portfolio.id for _ = 1:length(portfolio.pendingorders)], [user.id for _ = 1:length(portfolio.pendingorders)]); executemany=true)
    # update completedorders
    # execute("""
    #     DELETE FROM completedorders WHERE portfolio_id = ? AND userid = ?
    # """, (portfolio.id, user.id))
    # execute("""
    #     INSERT INTO completedorders (portfolio_id, userid, transaction_id) VALUES (?, ?, ?)
    # """, ([portfolio.id for _ = 1:length(portfolio.completedorders)], [user.id for _ = 1:length(portfolio.completedorders)], portfolio.completedorders); executemany=true)
    execute("""
        UPDATE completedorders
        SET transaction_id = ?
        WHERE portfolio_id = ? AND userid = ?
    """, (portfolio.completedorders, [portfolio.id for _ = 1:length(portfolio.completedorders)], [user.id for _ = 1:length(portfolio.completedorders)]); executemany=true)
    return
end

function get(id)
    user = Contexts.getuser()
    Strapping.construct(Portfolio, execute("""
        SELECT A.id, A.userid, A.name, A.cash, A.timespicked, B.ticker as holdings, C.transaction_id as pendingorders, D.transaction_id as completedorders FROM portfolio A
        INNER JOIN holdings B ON A.id = B.portfolio_id AND A.userid = B.userid
        INNER JOIN pendingorders C ON A.id = C.portfolio_id AND A.userid = C.userid
        INNER JOIN completedorders D ON A.id = D.portfolio_id AND A.userid = D.userid
        WHERE id = ? AND A.userid = ?
    """, (id, user.id)))
end

function delete(id)
    user = Contexts.getuser()
    execute("""
        DELETE FROM portfolio WHERE id = ? AND userid = ?
    """, (id, user.id))
    execute("""
        DELETE FROM holdings WHERE portfolio_id = ? AND userid = ?
    """, (id, user.id))
    execute("""
        DELETE FROM pendingorders WHERE portfolio_id = ? AND userid = ?
    """, (id, user.id))
    execute("""
        DELETE FROM completedorders WHERE portfolio_id = ? AND userid = ?
    """, (id, user.id))
    return
end

function getAllPortfolios()
    user = Contexts.getuser()
    Strapping.construct(Vector{Portfolio}, execute("""
        SELECT A.id, A.userid, A.name, A.cash, A.timespicked, B.ticker as holdings, C.transaction_id as pendingorders, D.transaction_id as completedorders FROM portfolio A
        INNER JOIN holdings B ON A.id = B.portfolio_id AND A.userid = B.userid
        INNER JOIN pendingorders C ON A.id = C.portfolio_id AND A.userid = C.userid
        INNER JOIN completedorders D ON A.id = D.portfolio_id AND A.userid = D.userid
        WHERE A.userid = ?
    """, (user.id,)))
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