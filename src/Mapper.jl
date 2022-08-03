module Mapper
# storage layer for passing model objects into

using ..Model, ..Contexts, ..ConnectionPools
using SQLite, DBInterface, Strapping, Tables

# pod is a specific key to a pool of SQLite database connections
const DB_POOL = Ref{ConnectionPools.Pod{ConnectionPools.Connection{SQLite.DB}}}()
const PORTFOLIO_COUNTER = Ref{Int64}(0)
const MM_COUNTER = 30 # reserved IDs for non-native (e.g., market maker) orders

# define the normalized relational database where we store holdings Vector as seperate tables
# we use these database connections to store the objects we defined in Model.jl
# database config options in 2nd line of function correspond to Pod Struct defined in ConnectionPools.jl
# the additional execute methods create indices on the columns we'll be filtering on (helps with speed)
function init(dbfile)
    new = () -> SQLite.DB(dbfile)
    DB_POOL[] = ConnectionPools.Pod(SQLite.DB, Threads.nthreads(), 60, 1000, new)
    PORTFOLIO_COUNTER[] += MM_COUNTER
    if !isfile(dbfile)
        db = SQLite.DB(dbfile)
        # TODO: Make portfolio id UNIQUE
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
                ticker TEXT,
                shares INTEGER
            )
        """)
        # DBInterface.execute(db, """
        #     CREATE TABLE holdings (
        #         portfolio_id INTEGER,
        #         userid INTEGER,
        #         ticker INTEGER,
        #         shares REAL
        #     )
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
    portfolio.id = PORTFOLIO_COUNTER[] += 1
    execute("""
        INSERT INTO portfolio (id, userid, name, cash, timespicked) VALUES(?, ?, ?, ?, ?)
    """, (portfolio.id, portfolio.userid, portfolio.name, portfolio.cash, portfolio.timespicked))
    id = portfolio.id
    execute("""
        INSERT INTO holdings (portfolio_id, userid, ticker, shares) VALUES (?, ?, ?, ?)
    """, ([id for _ = 1:length(portfolio.holdings)], [user.id for _ = 1:length(portfolio.holdings)], [String(i) for i in keys(portfolio.holdings)], [i for i in values(portfolio.holdings)]); executemany=true)
    # execute("""
    #     INSERT INTO holdings (portfolio_id, userid, ticker, shares) VALUES (?, ?, ?, ?)
    # """, ([id for _ = 1:length(portfolio.ticker)], [user.id for _ = 1:length(portfolio.ticker)], portfolio.ticker, portfolio.shares); executemany=true)
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
        INSERT INTO holdings (portfolio_id, userid, ticker, shares) VALUES (?, ?, ?, ?)
    """, ([portfolio.id for _ = 1:length(portfolio.holdings)], [user.id for _ = 1:length(portfolio.holdings)], [String(i) for i in keys(portfolio.holdings)], [i for i in values(portfolio.holdings)]); executemany=true)
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

function update_holdings(id, holdings)
    user = Contexts.getuser()
    execute("""
        DELETE FROM holdings WHERE portfolio_id = ? AND userid = ?
    """, (id, user.id))
    execute("""
        INSERT INTO holdings (portfolio_id, userid, ticker, shares) VALUES (?, ?, ?, ?)
    """, ([id for _ = 1:length(holdings)], [user.id for _ = 1:length(holdings)], [String(i) for i in keys(holdings)], [i for i in values(holdings)]); executemany=true)
    return
end

function update_cash(id, cash)
    user = Contexts.getuser()
    execute("""
        UPDATE portfolio
        SET cash = ?
        WHERE id = ?
    """, (cash, id))
    return
end

# function get(id)
#     user = Contexts.getuser()
#     Strapping.construct(Portfolio, execute("""
#         SELECT A.id, A.userid, A.name, A.cash, A.timespicked, B.ticker as ticker, B.shares as shares, C.transaction_id as pendingorders, D.transaction_id as completedorders FROM portfolio A
#         INNER JOIN holdings B ON A.id = B.portfolio_id AND A.userid = B.userid
#         INNER JOIN pendingorders C ON A.id = C.portfolio_id AND A.userid = C.userid
#         INNER JOIN completedorders D ON A.id = D.portfolio_id AND A.userid = D.userid
#         WHERE id = ? AND A.userid = ?
#     """, (id, user.id)))
# end
function getHoldings(id)
    user = Contexts.getuser()
    cursor = execute("SELECT ticker, shares FROM holdings WHERE portfolio_id = ? AND userid = ?", (id, user.id))
    tick_share_table = cursor |> columntable # returns NamedTuple of holdings
    ticker_keys = Tuple(Symbol.(tick_share_table[:ticker]))
    share_vals = Tuple(tick_share_table[:shares])
    holdings = (; zip(ticker_keys, share_vals)...)
    return holdings
end

function getCash(id)
    cursor = execute("SELECT cash FROM portfolio WHERE id = ?", (id,))
    cash_table = cursor |> columntable
    cash = cash_table[:cash][1]
    return cash
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

# function getAllPortfolios()
#     user = Contexts.getuser()
#     Strapping.construct(Vector{Portfolio}, execute("""
#         SELECT A.id, A.userid, A.name, A.cash, A.timespicked, B.ticker as ticker, B.shares as shares, C.transaction_id as pendingorders, D.transaction_id as completedorders FROM portfolio A
#         INNER JOIN holdings B ON A.id = B.portfolio_id AND A.userid = B.userid
#         INNER JOIN pendingorders C ON A.id = C.portfolio_id AND A.userid = C.userid
#         INNER JOIN completedorders D ON A.id = D.portfolio_id AND A.userid = D.userid
#         WHERE A.userid = ?
#     """, (user.id,)))
# end

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