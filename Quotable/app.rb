require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
require "byebug"
require_relative "./model.rb"
require "sinatra/reloader"
also_reload "./model.rb"
enable :sessions
include Model #Makes this possible

# Checks that the user is an admin before all the admin pages or otherwise redirects them
#
before /\/(quotes\/new\/|origin\/new\/|quotes\/edit\/|quotes\/edit\/update|quotes\/edit\/delete|origin\/edit\/|origin\/edit\/update)/ do
    admin = is_admin(session[:logged_in]) 
    if admin == false
        redirect("/quotes/")
    end
end

# Checks if user has logged in before the cart and library otherwise redirects them to the login page
#
before /\/(user\/show\/|cart\/)/ do 
    if session[:logged_in] == nil
        redirect("/user/")
    end
end

# Displays the landingpage
#
get("/") do 
    slim(:index)
end

# Displays the login page
#
get("/user/") do
    slim(:"user/index")
end

# Displays the register page
#
get("/user/new/") do
    slim(:"user/new")                   #Kolla över verifieringen ifall man försöker uppdatera eller deleta quotes/origins så att man är admin
end

# Displays the users library
#
# @param [String] colums the column names delimited by (,space) 
# @param [String] quotes the name of the first table
# @param [String] library the name of the second table
# @param [String] togheter what the two tables have togheter
# @param [String] library.user_id a condition that looks at the user_id
# @param [String] session[:logged_in] the user_id of the user
#
# @see Model#join_from_db
get("/user/show/") do
    user_library = join_from_db("quotes.quote_id, quote, earnings", "quotes", "library", "library.quote_id = quotes.quote_id", "library.user_id", session[:logged_in])
    said_quote = session[:said_quote]
    session[:said_quote] = nil
    slim(:"user/show", locals:{user_library: user_library, said_quote: said_quote})
end

# Displays the main quote store
#
# @param [String] columns the columns that is to be selected
# @param [String] quotes the table that the information will come from
#
# @see Model#get_from_db
get("/quotes/") do
    quotes = get_from_db("quote_id, quote, price", "quotes")
    slim(:"quotes/index", locals:{quotes: quotes})
end

# Displays the updating page for quotes
#
# @param [String] columns the columns that is to be selected
# @param [String] quotes the table that the information will come from
#
# @see Model#get_from_db
get("/quotes/edit/") do
    quotes = get_from_db("quote_id, quote, price, earnings, origin_id", "quotes")
    slim(:"quotes/edit", locals:{quotes: quotes})
end

# Displays a single quote
#
# @param [String] quote_id the column that is to be selected
# @param [String] quotes the table that the information will come from
# @param [String] condition a optional condition to be checked 
# @param [Integer] :quote_id the displaying quotes id
# @param [integer] session[:logged_in] the current users id
#
# @see Model#get_from_db
# @see Model#owned_quote
get("/quotes/:quote_id") do
    quote_id = params["quote_id"]
    found_quote = get_from_db("quote_id", "quotes", "quote_id", "#{quote_id}")
    if found_quote.empty?
        redirect("/quotes/")
    end
    owned = owned_quote(quote_id, session[:logged_in])
    quote_information = join_from_db("quote, price, earnings, person, backstory", "quotes", "origin", "quotes.origin_id = origin.origin_id", "quotes.quote_id", "#{quote_id}")[0]
    slim(:"quotes/show", locals:{quote_information: quote_information, quote_id: quote_id, owned: owned})
end

# Displays the page where an admin can add new quotes
#
# @param [String] columns the columns that is to be selected
# @param [String] origin the table that the information will come from
#
# @see Model#get_from_db
get("/quotes/new/") do
    origin = get_from_db("origin_id, person, backstory", "origin")
    slim(:"quotes/new", locals:{origin: origin})
end

# Displays the users shoppingcart
#
# @param [String] columns the column names delimited by (,space) 
# @param [String] quotes the name of the first table
# @param [String] cart the name of the second table
# @param [String] togheter what they have togheter
# @param [String] cart.user_id looks for the user_id
# @param [String] session[:logged_in] the user_id from the user
#
# @see Model#join_from_db
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

# Displays the page where an admin can create new origins
#
get("/origin/new/") do 
    slim(:"origin/new") 
end

# Displays the page where an admin can edit existing origins
#
# @param [String] columns the columns that is to be selected
# @param [String] origin the table that the information will come from
#
# @see Model#get_from_db
get("/origin/edit/") do 
    origins = get_from_db("origin_id, person, backstory", "origin")
    slim(:"origin/edit", locals:{origins: origins})
end

# Tries to login the user
#
# @param [Array] session[:time_checker] Array containing the times when the user tries to login
# 
# @param [String] column the column/columns that is to be selected
# @param [String] user the table that the information will come from
# @param [String] condition_username a condition that looks for the username 
# @param [String] username the inputed username
#
# @param [String] password the inputed password
# @param [String] username the inputed username
#
# @see Model#time_checker
# @see Model#get_from_db
# @see Model#password_checker
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
    if password_checker(password, username) == true
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

# Regisers a new user
#
# @param [String] username the inputed username
# @param [String] password the inputed password
# @param [String] password_verify the verifier password
#
# @param [String] username the column that is to be selected
# @param [String] user the table that the information will come from
# @param [String] condition_username a condition that looks for the username 
# @param [String] username the inputed username
#
# @param [String] user the table where the data should go
# @param [String] columns which columns the data should go in
# @param [String] "?,?,?" amount of columns in (?)
# @param [Array] values containing the values to be put in the columns 
#
# @see Model#input_check
# @see Model#get_from_db
# @see Model#insert_into_db
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

# Adds the quota earned from saying the quote
#
# @param [String] earnings the column that is to be selected
# @param [String] quotes the table that the information will come from
# @param [String] condition_quote_id a condition that looks att quote_id 
# @param [String] quote_id the value of the conition
#
# @param [String] user the table name
# @param [String] colum the column name and what it should be updated to
# @param [String] condition_user_id a condition that looks att the user_id
# @param [String] session[:logged_in] the user_id of the user
#
# @see Model#get_from_db
# @see Model#update_db
post("/user/show") do 
    quote_id = params[:quote_id]
    earnings = get_from_db("earnings", "quotes", "quote_id", quote_id)[0]["earnings"]
    session[:said_quote] = params[:quote]
    session[:quota] += earnings       
    
    update_db("user", "quota = quota + #{earnings}", "user_id", session[:logged_in])
    redirect("/user/show/")
end

# Buy the users shoppingcart and adds them to the library
#
# @param [String] price the column name 
# @param [String] quotes the name of the first table
# @param [String] cart the name of the second table
# @param [String] togheter what they have togheter
# @param [String] cart.user_id a condition that looks for a specific user_id
# @param [String] session[:logged_in] the specific user_id to be looked at
#
# @param [String] quota the column that is to be selected
# @param [String] user the table that the information will come from
# @param [String] condition_user_id a condition that looks for a specific user_id 
# @param [String] session[:logged_in] the specific user_id
#
# @param [String] user the table name
# @param [String] colum the column name and what it should be updated to
# @param [String] condition_user_id a condition that has to be true
# @param [String] value value of the condition 
#
# @param [String] library the tablename on the new table
# @param [String] cart the name of the old table containing the data
# @param [String] condition_user_id a condition that looks for a specific user_id 
# @param [String] session[:logged_in] the specific user_id
#
# @param [String] cart the table name
# @param [String] condition_user_id a condition that looks for a specific user_id 
# @param [String] session[:logged_in] the specific user_id
#
# @see Model#join_from_db
# @see Model#get_from_db
# @see Model#update_db
# @see Model#big_insert_into_db
# @see Model#delete_db
post("/library/new") do 
    user_cart = params[:user_cart].split('').map(&:to_i)
    prices = join_from_db("price", "quotes", "cart", "cart.quote_id = quotes.quote_id", "cart.user_id", session[:logged_in])
    user_quota = get_from_db("quota", "user", "user_id", session[:logged_in])[0]["quota"]
    total_price = 0
    
    prices.each do |price|
        total_price += price["price"]
    end

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

# Sets all session cokies to nil
#
post("/quotes") do
    session.destroy
    redirect("/")
end

# Creates a new quote 
#
# @param [Integer] session[:logged_in] the users id
#
# @param [String] quotes the table where the data should go
# @param [String] columns which columns the data should go in
# @param [String] "?,?,?,?" amount of columns in (?)
# @param [Array] values containing the values to be put in the columns
#
# @see Model#is_admin
# @see Model#insert_into_db
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

# Updates the quote information for a specific quote
#
# @param [String] quotes the table name
# @param [String] columns the columns name
# @param [String] condition_quote_id a condition that looks for a specific quote_id
# @param [String] quote_id the specific quote_id
#
# @see Model#update_db
post("/quotes/edit/update") do
    quote_id = params[:update_button]
    new_quote = params[:new_quote]
    new_price = params[:new_price]
    new_earnings = params[:new_earnings]
    new_origin_id = params[:new_origin_id] #OBS kolla här och se ifall detta är ett problem. Blir samma senare isåfall
    update_db("quotes", "quote = '#{new_quote}', price = #{new_price}, earnings = #{new_earnings}, origin_id = #{new_origin_id}", "quote_id", "#{quote_id}")
    redirect("/quotes/edit/")
end

# Detetes a quote and all its information
#
# @param [String] quotes the table name
# @param [String] condition_quote_id a condition that looks for a specific quote_id
# @param [String] quote_id the specific quote_id
#
# @see Model#delete_db
post("/quotes/edit/delete") do
    quote_id = params[:delete_button]
    delete_db("quotes", "quote_id", "#{quote_id}", "quote_id", "#{quote_id}")
    redirect("/quotes/edit/")
end

# Creates a new origin 
#
# @param [Integer] session[:logged_in] the users id
#
# @param [String] origin the table where the data should go
# @param [String] columns which columns the data should go in
# @param [String] "?,?" amount of columns in (?)
# @param [Array] values containing the values to be put in the columns
#
# @see Model#is_admin
# @see Model#insert_into_db
post("/origin/new") do 
    person = params[:person]
    backstory = params[:backstory]
    admin = is_admin(session[:logged_in])
    if admin == true
        insert_into_db("origin", "person, backstory", "?, ?", ["#{person}", "#{backstory}"])
    end
        redirect("/origin/new/")
end

# Updates the origin information for a specific origin
#
# @param [String] origin the table name
# @param [String] columns the columnns name and what they should be
# @param [String] condition_origin_id a condition that looks for a specific origin_id
# @param [String] origin_id the specific origin_id 
#
# @see Model#update_db
post("/origin/edit/update") do
    origin_id = params[:update_button]
    new_person = params[:new_person]
    new_backstory = params[:new_backstory]
    update_db("origin", "person = '#{new_person}', backstory = '#{new_backstory}'", "origin_id", "#{origin_id}")
    redirect("/origin/edit/")
end

# Detetes one item in the cart for the user
#
# @param [String] cart the table name
# @param [String] condition_quote_id a condition that looks for a specific quote_id
# @param [String] quote_id the specific quote_id
#
# @see Model#delete_db
post("/cart") do 
    quote_id = params[:quote_id]
    delete_db("cart", "user_id", session[:logged_in], "quote_id", quote_id)
    redirect("/cart/")
end

# Adds a new quote to the shoppingcart
#
# @param [Integer] quote_id the quotes id to be checked
# @param [Integer] user_id the id of the user
#
# @param [String] cart the table where the data should go
# @param [String] columns which columns the data should go in
# @param [String] "?,?" amount of columns in (?)
# @param [Array] values containing the values to be put in the columns
#
#@see Model#owned_quote
#@see Model#insert_into_db
post("/cart/new") do 
    quote_id = params[:quote_id]
    if owned_quote(quote_id, session[:logged_in]) == false
        session[:special_error] = nil
        insert_into_db("cart", "user_id, quote_id", "?, ?", [session[:logged_in], "#{quote_id}"])
    else 
        session[:special_error] = [quote_id, "(Du äger redan denna quote eller har den i kundvagnen)"]
        redirect("/quotes/")
    end
    redirect("/quotes/")
end