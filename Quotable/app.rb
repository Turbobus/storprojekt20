require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
enable :sessions
db = SQLite3::Database.new("db/quotables.db")
db.results_as_hash = true

get("/") do 
    slim(:index)
end

get("/user/new") do
    slim(:"user/new")
end

get("/user/index") do
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
        redirect("/password_do_not_match")                                      #Måste ändra   OBS!!!!!
    end
    
    only_integer = password.scan(/\D/).empty?
    only_letters = password.scan(/\d/).empty? 
    if only_integer == true || only_letters == true || password.length > 3
        redirect("/password_do_not_match")         #OBS ska ändras   Blir här när det bara är siffror eller bara bokstäver eller när det är under 4 tecken
    end

    exist = db.execute("SELECT username FROM user WHERE username LIKE ?", username)
    password_scramble = BCrypt::Password.create(password)

    if exist.empty?
        db.execute("INSERT INTO user(username, password, quota) VALUES(?, ?)", username, password_scramble, starting_quota)
    else
        redirect("/username_exist")                                            #Måste ändra   OBS!!!!!
    end
    redirect("/")
end