require "bcrypt"
# Makes commenting possible
#
module Model
    # Connects to the specified database file
    #
    # @return [Array] containing databasefile
    #
    def db()
        db = SQLite3::Database.new("db/quotables.db")
        db.results_as_hash = true
        return db
    end

    # Verifies that the input data from a new user is correct 
    #
    # @param [String] username the inputed username
    # @param [String] password the inputed user password
    # @param [String] password_verify the inputed controller password
    #
    # @return [String] containing information about if the inputed values were allowed
    #
    def input_chek(username, password, password_verify)
        if password != password_verify || username == "" || password == "" 
            return "input_false"                                    
        end

        only_integer = password.scan(/\D/).empty?
        only_letters = password.scan(/\d/).empty? 
        if only_integer == true || only_letters == true || password.length < 4 || password.length > 20
            return "password_false"   
        end
        return BCrypt::Password.create(password)
    end

    # Checks if the inputed password is the same as in the database
    #
    # @param [String] password the inputed password to the user
    # @param [String] username the username that tries to log in
    #
    # @return [Boolean] returns true/false based on if the inputed password matches the registerd password 
    #
    def password_checker(password, username)
        controll_password = get_from_db("password", "user", "username", username)[0]["password"]
        if BCrypt::Password.new(controll_password) == password
            return true
        else
            return false                  
        end
    end

    # Finds out how many times the user has tried to login in the last 60 seconds to protect from spam login
    #
    # @param [Array] time_array containing the times the user tries to login
    #
    # @return [Boolean] returns true/false based on if the user has tried to login more than 3 times in the last 60 seconds
    #
    def time_checker(time_array)
        time_array.each do |time|
            if time_array[time_array.length - 1] - time > 60  
                time_array.delete(time)
            end
        end
        if time_array.length > 3
            return false
        else
            return true
        end
    end

    # Checks if the user is an admin
    #
    # @param [Integer] user_id the users id
    #
    # @return [Boolean] based on if the user is an admin
    #
    def is_admin(user_id)
        admin = get_from_db("admin", "user", "user_id", session[:logged_in])[0]["admin"] if session[:logged_in] != nil
        if admin == 1 
            return true
        else
            return false
        end
    end

    # Checks if the inputed line is nil
    #
    # @param [String] line to be checked if nil
    #
    # @return [Boolean] based on if the inputed line was nil
    #
    def is_nil(line)
        if line == nil
            return true
        else 
            return false
        end
    end

    # Finds out if the user owns or has in cart a specific quote
    #
    # @param [Integer] quote_id the quotes id to be checked
    # @param [Integer] user_id the id of the user
    #
    # @return [Boolean] whether the user owns/have in cart the quote
    #
    def owned_quote(quote_id, user_id)
        owned_quote = get_from_db("quote_id", "library", "quote_id", "#{quote_id}", "user_id", "#{user_id}")[0]
        have_in_cart = get_from_db("quote_id", "cart", "quote_id", "#{quote_id}", "user_id", "#{user_id}")[0]
        if is_nil(owned_quote) == false || is_nil(have_in_cart) == false
            return true
        else
            return false
        end
    end

    # Gets information out from the database based on inputed values
    #
    # @param [String] colum the column/columns that is to be selected
    # @param [String] table the table that the information will come from
    # @param [String] condition a optional condition to be checked 
    # @param [String] value value of the condition to be checked
    # @param [String] condition2 another optional condtition to be checked 
    # @param [String] value2 vale of the second condition to be checked
    #
    # @return [Array] containing hash with the specified information from the database
    #
    def get_from_db(colum, table, condition = nil, value = nil, condition2 = nil, value2 = nil)
        if condition2 == nil
            information = db.execute("SELECT #{colum} FROM #{table}#{condition == nil ? "" : " WHERE #{condition} LIKE ?"}", value)
        else 
            information = db.execute("SELECT #{colum} FROM #{table} WHERE #{condition} LIKE ? AND #{condition2} LIKE ?", value, value2)
        end
        return information
    end

    # Inserts inputed information to the database
    #
    # @param [String] table the table where the data should go
    # @param [String] colums which column/columns the data should go in
    # @param [String] numbers containing ? based on the amount of columns that where put in
    # @param [Array] values containing the values to be put in the columns 
    #
    def insert_into_db(table, colums, numbers, values)
        db.execute("INSERT INTO #{table} (#{colums}) VALUES(#{numbers})", values)
    end

    # Copies data from one table to another
    #
    # @param [String] newtable the tablename on the new table
    # @param [String] oldtable the name of the old table containing the data
    # @param [String] condition a condition that has to be true
    # @param [String] value the value of the condition
    #
    def big_insert_into_db(newtable, oldtable, condition, value)
        db.execute("INSERT INTO #{newtable} SELECT * FROM #{oldtable} WHERE #{condition} LIKE ?", value)
    end

    # Updates data in the database
    #
    # @param [String] table the table name
    # @param [String] colum the column name and what it should be updated to
    # @param [String] condition a condition that has to be true
    # @param [String] value value of the condition 
    #
    def update_db(table, colum, condition, value)
        db.execute("UPDATE #{table} SET #{colum} WHERE #{condition} LIKE ?", value)
    end

    # Deletes specified data from the database
    #
    # @param [String] table the table name
    # @param [String] condition1 a condition that needs to be true
    # @param [String] value1 the value of the first condition
    # @param [String] condition2 a second condition that needs to be true or a repeat of the first if not needed
    # @param [String] value2 the value of the second condition or a repeat of the first if not needed
    #
    def delete_db(table, condition1, value1, condition2, value2)
        db.execute("DELETE FROM #{table} WHERE #{condition1} LIKE ? AND #{condition2} LIKE ?", value1, value2)
    end

    # Does a inner join funktion to take out information from two different tables
    #
    # @param [String] colums the column names 
    # @param [String] table1 the name of the first table
    # @param [String] table2 the name of the second table
    # @param [String] togheter what they have togheter
    # @param [String] condition a condition that needs to be true
    # @param [String] value the value of the condition
    #
    # @return [Array] containing hash with the specified data
    #
    def join_from_db(colums, table1, table2, togheter, condition, value)
        information = db.execute("SELECT #{colums} FROM #{table1} INNER JOIN #{table2} ON #{togheter} WHERE #{condition} LIKE ?", value)
        return information
    end
end