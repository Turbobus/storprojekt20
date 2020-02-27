require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
require "byebug"
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
    if session[:logged_in] != nil
        username = get_from_db("username", "user", "user_id", session[:logged_in])[0]["username"]
    end

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

    if exist.empty?
        insert_into_db("user", "username, password, quota", "?, ?, ?", ["#{username}", "#{controller}", 1])
        session[:logged_in] = get_from_db("user_id", "user", "username", username)[0]["user_id"]
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
    exist = get_from_db("username", "user", "username", username)
    if exist.empty?
        redirect("/Användare existerar inte")               #MÅSTE ändra OBS!!!!!!!!!!!!
    end

    #Hämtar användarens lödsenord för jämförelse
    password_chek = password_checker(password, username)
    
    if password_chek == true
        session[:logged_in] = get_from_db("user_id", "user", "username", username)[0]["user_id"]
        redirect("/quotes/")
    else
        redirect("/Password incorrect")                  #Måste ändra OBS!!!!!!!
    end
end

#Helper funktioner nedanför
