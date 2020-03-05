require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
require "byebug"
require_relative "./model.rb"
require "sinatra/reloader"
enable :sessions
db = SQLite3::Database.new("db/quotables.db")
db.results_as_hash = true

get("/") do 
    slim(:index)
end

get("/user/") do
    slim(:"user/index")
end

get("/user/new/") do
    slim(:"user/new")
end

get("/user/show/") do
    user_library = join_from_db("quotes.quote_id, quote, earnings", "quotes", "library", "library.quote_id = quotes.quote_id", "library.user_id", session[:logged_in])
    said_quote = session[:said_quote]
    session[:said_quote] = nil

    slim(:"user/show", locals:{user_library: user_library, said_quote: said_quote})
end

get("/quotes/") do
    if session[:logged_in] != nil
        username = get_from_db("username", "user", "user_id", session[:logged_in])[0]["username"]
        admin = get_from_db("admin", "user", "user_id", session[:logged_in])[0]["admin"]
    end
    quotes = get_from_db("quote_id, quote, price", "quotes")
    slim(:"quotes/index", locals:{username: username, admin: admin, quotes: quotes})
end

get("/quotes/:quote_id") do
    quote_id = params["quote_id"]
    #Verifiering av quote_id behövs att göras så att det faktisk finns där
    quote_information = join_from_db("quote, price, earnings, person, backstory", "quotes", "origin", "quotes.origin_id = origin.origin_id", "quotes.quote_id", "#{quote_id}")[0]
    slim(:"quotes/show", locals:{quote_information: quote_information})
end

get("/cart/") do 
    user_cart = join_from_db("quotes.quote_id, quote, price, earnings", "quotes", "cart", "cart.quote_id = quotes.quote_id", "cart.user_id", session[:logged_in])
    
    quote_ids = ""
    total_price = 0
    user_cart.each do |quote|
        quote_ids += quote["quote_id"].to_s
        total_price += quote["price"]
    end
    slim(:"cart/index", locals:{user_cart: user_cart, quote_ids: quote_ids, total_price: total_price})
end

get("/quotes/new/") do
    origin = get_from_db("origin_id, person, backstory", "origin") 
    slim(:"quotes/new", locals:{origin: origin})
end

get("/origin/") do
    slim(:"origin/index")
end

get("/origin/new/") do 
    slim(:"origin/new")
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

post("/user/show") do 
    quote_id = params[:quote_id]
    earnings = get_from_db("earnings", "quotes", "quote_id", quote_id)[0]["earnings"]
    session[:said_quote] = params[:quote]       
    
    update_db("user", "quota = quota + #{earnings}", "user_id", session[:logged_in])
    redirect("/user/show/")
end

post("/library/new") do 
    user_cart = params[:user_cart].split('').map(&:to_i)
    prices = join_from_db("price", "quotes", "cart", "cart.quote_id = quotes.quote_id", "cart.user_id", session[:logged_in])
    total_price = 0
    
    prices.each do |price|
        total_price += price["price"]
    end

    user_quota = get_from_db("quota", "user", "user_id", session[:logged_in])[0]["quota"]

    if total_price > user_quota
        p "det gick inte"
        redirect("/You dont have the quota to do that")      #Måste ändra här med   OBS!!!!!!!!!!!
    end
    
    update_db("user", "quota = quota - #{total_price}", "user_id", session[:logged_in])
    big_insert_into_db("library", "cart", "user_id", session[:logged_in])
    delete_db("cart", "user_id", session[:logged_in])
    redirect("/cart/")
end

post("/quotes") do
    session[:logged_in] = nil
    redirect("/")
end

post("/quotes/new") do
    quote = params[:quote]
    price = params[:price]
    earnings = params[:earnings]
    origin_id = params[:origin_id]

    insert_into_db("quotes", "quote, price, earnings, origin_id", "?, ?, ?, ?", ["#{quote}", "#{price}", "#{earnings}", "#{origin_id}"])
    redirect("/quotes/new/")
end

post("/origin/new") do 
    person = params[:person]
    backstory = params[:backstory]
    
    insert_into_db("origin", "person, backstory", "?, ?", ["#{person}", "#{backstory}"])
    redirect("/origin/new/")
end

post("/cart/new") do 
    user_id = session[:logged_in]
    quote_id = params[:quote_id]
    insert_into_db("cart", "user_id, quote_id", "?, ?", ["#{user_id}", "#{quote_id}"])
    redirect("/quotes/")
end
#Helper funktioner nedanför
