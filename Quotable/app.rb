require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
enable :sessions
db = SQLite3::Database.new("db/todo_login.db")
db.results_as_hash = true

get("/") do 
    slim(:index)
end

get("/user/new") do
    slim(:"user/new")
end

get("/user/login") do
    slim(:"user/login")
end

get("/quotes") do 
    slim(:"quotes/index")
end