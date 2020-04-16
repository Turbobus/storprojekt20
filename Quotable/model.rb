require "bcrypt"
module Model
    def conect_to_db()
        db = SQLite3::Database.new("db/quotables.db")
        db.results_as_hash = true
        return db
    end

    def input_chek(username, password, password_verify)
        if password != password_verify || username == "" || password == "" 
            return "input_true"                                    
        end

        only_integer = password.scan(/\D/).empty?
        only_letters = password.scan(/\d/).empty? 
        if only_integer == true || only_letters == true || password.length < 4
            return "password_true"   
        end
        return BCrypt::Password.create(password)
    end

    def password_checker(password, username)
        controll_password = get_from_db("password", "user", "username", username)[0]["password"]
        if BCrypt::Password.new(controll_password) == password
            return true
        else
            return false                  
        end
    end

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

    def is_admin(user_id)
        admin = get_from_db("admin", "user", "user_id", session[:logged_in])[0]["admin"] if session[:logged_in] != nil
        if admin == 1 
            return true
        else
            return false
        end
    end

    def is_nil(line)
        if line == nil
            return true
        else 
            return false
        end
    end

    def get_from_db(colum, table, condition = nil, value = nil)
        db = conect_to_db()
        information = db.execute("SELECT #{colum} FROM #{table}#{condition == nil ? "" : " WHERE #{condition} LIKE ?"}", value)
        return information
    end

    def insert_into_db(table, colums, numbers, values)
        db = conect_to_db()
        db.execute("INSERT INTO #{table} (#{colums}) VALUES(#{numbers})", values)
    end

    def big_insert_into_db(newtable, oldtable, condition, value)
        db = conect_to_db()
        db.execute("INSERT INTO #{newtable} SELECT * FROM #{oldtable} WHERE #{condition} LIKE ?", value)
    end

    def update_db(table, colum, condition, value)
        db = conect_to_db()
        db.execute("UPDATE #{table} SET #{colum} WHERE #{condition} LIKE ?", value)
    end

    def delete_db(table, condition1, value1, condition2, value2)
        db = conect_to_db
        db.execute("DELETE FROM #{table} WHERE #{condition1} LIKE ? AND #{condition2} LIKE ?", value1, value2)
    end

    def join_from_db(colums, table1, table2, togheter, condition, value)
        db = conect_to_db()
        information = db.execute("SELECT #{colums} FROM #{table1} INNER JOIN #{table2} ON #{togheter} WHERE #{condition} LIKE ?", value)
        return information
    end
end