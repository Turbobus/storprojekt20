require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
require "byebug"
require_relative "./model.rb"
require "sinatra/reloader"
also_reload "./model.rb"
enable :sessions
include Model


before /\/(quotes\/new\/|origin\/new\/|quotes\/edit\/|quotes\/edit\/update|quotes\/edit\/delete|origin\/edit\/|origin\/edit\/update)/ do
    admin = is_admin(session[:logged_in]) 
    if admin == false
        redirect("/quotes/")
    end
end

before /\/(user\/show\/|cart\/)/ do 
    if session[:logged_in] == nil
        redirect("/user/")
    end
end

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
        admin = is_admin(session[:logged_in])
    end
    quotes = get_from_db("quote_id, quote, price", "quotes")
    
    slim(:"quotes/index", locals:{username: username, admin: admin, quotes: quotes})
end

get("/quotes/edit/") do
    quotes = get_from_db("quote_id, quote, price, earnings, origin_id", "quotes")
    slim(:"quotes/edit", locals:{quotes: quotes})
end

get("/quotes/:quote_id") do
    quote_id = params["quote_id"]
    found_quote = get_from_db("quote_id", "quotes", "quote_id", "#{quote_id}")
    if found_quote.empty?
        redirect("/quotes/")
    end
    owned_quote = get_from_db("quote_id", "library", "quote_id", "#{quote_id}", "user_id", "#{session[:logged_in]}")[0]
    have_in_cart = get_from_db("quote_id", "cart", "quote_id", "#{quote_id}", "user_id", "#{session[:logged_in]}")[0]
    if is_nil(owned_quote) == false || is_nil(have_in_cart) == false
        owned = true
    else
        owned = false
    end
    quote_information = join_from_db("quote, price, earnings, person, backstory", "quotes", "origin", "quotes.origin_id = origin.origin_id", "quotes.quote_id", "#{quote_id}")[0]
    slim(:"quotes/show", locals:{quote_information: quote_information, quote_id: quote_id, owned: owned})
end

get("/quotes/new/") do
    origin = get_from_db("origin_id, person, backstory", "origin")
    slim(:"quotes/new", locals:{origin: origin})
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

get("/origin/new/") do 
    slim(:"origin/new") 
end

get("/origin/edit/") do 
    origins = get_from_db("origin_id, person, backstory", "origin")
    slim(:"origin/edit", locals:{origins: origins})
end

post("/user") do
    username = params[:username]
    password = params[:password]
    session[:logged_in] = nil
    if session[:time_checker] == nil
        session[:time_checker] = []
    end
    session[:time_checker] << Time.now.to_i
    if time_checker(session[:time_checker]) == false
        session[:error_message] = "Time out, vänta i 60 sekunder innan du försöker igen"
        redirect("/user/")               
    end

    #Kollar ifall Användaren finns
    exist = get_from_db("username", "user", "username", username)
    if exist.empty?
        session[:error_message] = "Användarnamnet eller lösenordet är fel, försök igen"
        redirect("/user/")
    end

    #Hämtar användarens lödsenord för jämförelse
    password_chek = password_checker(password, username)
    
    if password_chek == true
        user_info = get_from_db("user_id, quota, admin", "user", "username", username)[0]
        session[:logged_in] = user_info["user_id"]
        session[:quota] = user_info["quota"]
        session[:admin] = user_info["admin"]
        session[:username] = username
        session[:error_message] = nil
        redirect("/quotes/")
    else
        session[:error_message] = "Användarnamnet eller lösenordet är fel, försök igen"
        redirect("/user/")
    end
end

post("/user/new") do 
    username = params[:username]
    password = params[:password]
    password_verify = params[:password_verify]

    controller = input_chek(username, password, password_verify)
    if  controller == "input_false"
        session[:error_message] = "Lösenorden matchar inte"
        redirect("/user/new/")
    end
    
    if controller == "password_false"
        session[:error_message] = "Lösenordet måste innehålla minst 1 siffra eller bokstav och vara mellan 4-20 karaktärer lång"
        redirect("/user/new/")
    end

    exist = get_from_db("username", "user", "username", username) 

    if exist.empty?
        insert_into_db("user", "username, password, quota", "?, ?, ?", ["#{username}", "#{controller}", 1])
        user_info = get_from_db("user_id, quota", "user", "username", username)[0]
        session[:logged_in] = user_info["user_id"]
        session[:quota] = user_info["quota"]
        session[:username] = username
        session[:error_message] = nil
    else
        session[:error_message] = "Användarnamnet existerar redan"
        redirect("/user/new/")
    end
    redirect("/quotes/")
end

post("/user/show") do 
    quote_id = params[:quote_id]
    earnings = get_from_db("earnings", "quotes", "quote_id", quote_id)[0]["earnings"]
    session[:said_quote] = params[:quote]
    session[:quota] += earnings       
    
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
        session[:error_message] = "Du har inte tillräkligt med Quota"
        redirect("/cart/")
    end
    
    update_db("user", "quota = quota - #{total_price}", "user_id", session[:logged_in])
    big_insert_into_db("library", "cart", "user_id", session[:logged_in])
    delete_db("cart", "user_id", session[:logged_in], "user_id", session[:logged_in])
    session[:quota] = get_from_db("quota", "user", "user_id", session[:logged_in])[0]["quota"]
    session[:error_message] = nil
    redirect("/cart/")
end

post("/quotes") do
    session.destroy
    redirect("/")
end

post("/quotes/new") do
    quote = params[:quote]
    price = params[:price]
    earnings = params[:earnings]
    origin_id = params[:origin_id]
    admin = is_admin(session[:logged_in])
    if admin == true
        insert_into_db("quotes", "quote, price, earnings, origin_id", "?, ?, ?, ?", ["#{quote}", "#{price}", "#{earnings}", "#{origin_id}"])
    end
    redirect("/quotes/new/")
end

post("/quotes/edit/update") do
    quote_id = params[:update_button]
    new_quote = params[:new_quote]
    new_price = params[:new_price]
    new_earnings = params[:new_earnings]
    new_origin_id = params[:new_origin_id]
    update_db("quotes", "quote = '#{new_quote}', price = #{new_price}, earnings = #{new_earnings}, origin_id = #{new_origin_id}", "quote_id", "#{quote_id}")
    redirect("/quotes/edit/")
end

post("/quotes/edit/delete") do
    quote_id = params[:delete_button]
    delete_db("quotes", "quote_id", "#{quote_id}", "quote_id", "#{quote_id}")
    redirect("/quotes/edit/")
end

post("/origin/new") do 
    person = params[:person]
    backstory = params[:backstory]
    admin = is_admin(session[:logged_in])
    if admin == true
        insert_into_db("origin", "person, backstory", "?, ?", ["#{person}", "#{backstory}"])
    end
        redirect("/origin/new/")
end

post("/origin/edit/update") do
    origin_id = params[:update_button]
    new_person = params[:new_person]
    new_backstory = params[:new_backstory]
    update_db("origin", "person = '#{new_person}', backstory = '#{new_backstory}'", "origin_id", "#{origin_id}")
    redirect("/origin/edit/")
end


post("/cart") do 
    quote_id = params[:quote_id]
    delete_db("cart", "user_id", session[:logged_in], "quote_id", quote_id)
    redirect("/cart/")
end

post("/cart/new") do 
    quote_id = params[:quote_id]
    if is_nil(session[:logged_in]) == false   
        owned_quote = get_from_db("quote_id", "library", "quote_id", "#{quote_id}", "user_id", "#{session[:logged_in]}")[0]
        have_in_cart = get_from_db("quote_id", "cart", "quote_id", "#{quote_id}", "user_id", "#{session[:logged_in]}")[0]
        if is_nil(owned_quote) == false || is_nil(have_in_cart) == false
            session[:special_error] = [quote_id, "(Du äger redan denna quote eller har den i kundvagnen)"]
            redirect("/quotes/") 
        else
            session[:special_error] = nil
            insert_into_db("cart", "user_id, quote_id", "?, ?", [session[:logged_in], "#{quote_id}"])
        end
    end
    redirect("/quotes/")
end