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

post("/register") do
    slim(:"user/new")
end