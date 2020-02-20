require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
require_relative "./model.rb"
enable :sessions
db = SQLite3::Database.new("db/quotables.db")
db.results_as_hash = true

get("/") do 
    slim(:index)
end

get("/user/new/") do
    slim(:"user/new")
end

get("/user/") do
    slim(:"user/index")
end

get("/quotes/") do
    username = username(session[:logged_in]) 
    slim(:"quotes/index", locals:{username: username})
end

post("/user/new") do 
    username = params[:username]
    password = params[:password]
    password_verify = params[:password_verify]

    controller = input_chek(username, password, password_verify)
    if  controller == "input_true"
        redirect("/empty_or_do_not_match")                                      #Måste ändra   OBS!!!!!
    end
    
    if controller == "password_true"
        redirect("/only_integer_or_letter_under_lengt3")         #OBS ska ändras   Blir här när det bara är siffror eller bara bokstäver eller när det är under 4 tecken
    end

    exist = get_from_db("username", "user", "username", username) 
    p controller
    if exist.empty?
        insert_into_db("user", "username, password, quota", "?, ?, ?", "#{username}, #{controller}, 1")
        session[:logged_in] = get_from_db("user_id", "user", "username", username[0]["user_id"])
    else
        redirect("/username_exist")                                            #Måste ändra   OBS!!!!!
    end
    redirect("/quotes/")
end

post("/user") do
    username = params[:username]
    password = params[:password]
    session[:logged_in] = nil

    #Kollar ifall Användaren finns
    exist = db.execute("SELECT username FROM user WHERE username LIKE ?", username)
    if exist.empty?
        redirect("/Användare existerar inte")               #MÅSTE ändra OBS!!!!!!!!!!!!
    end

    #Hämtar användarens lödsenord för jämförelse
    controll_password = db.execute("SELECT password FROM user WHERE username LIKE ?", username)[0]["password"]
    if BCrypt::Password.new(controll_password) == password
        session[:logged_in] = db.execute("SELECT user_id FROM user WHERE username LIKE ?", username)[0]["user_id"]
        redirect("/quotes/")
    else
        redirect("/Password incorrect")                  #Måste ändra OBS!!!!!!!
    end
end

#Helper funktioner nedanför

def username(user_id)
    db = SQLite3::Database.new("db/quotables.db")
    db.results_as_hash = true
    if user_id != nil
        username = db.execute("SELECT username FROM user WHERE user_id LIKE ?", user_id)[0]["username"]
    end
    return username
end