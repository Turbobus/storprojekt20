require "bcrypt"

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

def get_from_db(colum, table, condition, value)
    db = conect_to_db()
    information = db.execute("SELECT #{colum} FROM #{table} WHERE #{condition} LIKE ?", value)
    return information
end

def insert_into_db(table, colums, numbers, values)
    db = conect_to_db()
    p values
    db.execute("INSERT INTO #{table} (#{colums}) VALUES(#{numbers})", values)
end

