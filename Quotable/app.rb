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

post("/register") do 
    username = params[:username]
    password = params[:password]
    password_verify = params[:password_verify]
    starting_quota = 1

    if password != password_verify || username == "" || password == ""
        redirect("/password_do_not_match")
    end

    exist = db.execute("SELECT username FROM user WHERE username LIKE ?", username)
    password_scramble = BCrypt::Password.create(password)

    if exist.empty?
        db.execute("INSERT INTO user(username, password, quota) VALUES(?, ?)", username, password_scramble, starting_quota)
    else
        redirect("/username_exist")
    end
    redirect("/quotes")
end