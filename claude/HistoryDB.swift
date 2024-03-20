//
//  HistoryDB.swift
//  claude
//
//  Created by Tim Tully on 3/11/24.
//

import Foundation
import SQLite3

class HistoryDB {
    private init() {}
    
    static let shared = HistoryDB()
    
    static func getInstance() -> HistoryDB {
        return shared
    }
    
    var someProperty: String = "Initial value"
    
    func dbPathFile() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        let databasePath = (documentsPath?.appending("/database.sqlite"))!
        return databasePath
    }
    
    func openTable() -> OpaquePointer {
        let databasePath = self.dbPathFile()
        
        var db: OpaquePointer?
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            // Database opened successfully
        } else {
            // Failed to open database
            print("couldnt open table")
        }
        
        return db!;
    }
    
    func createTable(db:OpaquePointer) {
        let createTableQuery = "CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY AUTOINCREMENT, query TEXT, ts INTEGER)"
        var createTableStatement: OpaquePointer?
        let db = self.openTable()
        if sqlite3_prepare_v2(db, createTableQuery, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("Table created successfully")
            } else {
                print("Failed to create table")
            }
        } else {
            print("Failed to create table statement")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func insertQuery(query:String) {
        //let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        // Insert data
        let db = self.openTable()
        let insertQuery = "INSERT INTO history (id, query, ts) VALUES (?, ?, ?)"
        var insertStatement: OpaquePointer?
        let currentDate = Date()
        let unixTimestamp = currentDate.timeIntervalSince1970
        if sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK {
            // sqlite3_bind_int(insertStatement, 1, 0)
            if sqlite3_bind_text(insertStatement, 2, query, -1, SQLITE_TRANSIENT) != SQLITE_OK {
                print("couldnt bind text")
            }
            
            sqlite3_bind_int(insertStatement, 3, Int32(unixTimestamp))
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Data inserted successfully")
            } else {
                print("Failed to insert data")
                
                let errmsg = String(cString: sqlite3_errmsg(db))
                print("Error inserting statement: \(errmsg)")
            }
        } else {
            print("Failed to create insert statement")
        }
        sqlite3_finalize(insertStatement)
    }
    
    func getAll() -> [String]{
        var rv:[String] = [];
        let db = self.openTable()
        var statement: OpaquePointer?
        let query = "SELECT * FROM history order by id desc limit 10"
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Error preparing statement: \(errorMessage)")
            return []
        }
        
        // Execute the statement and retrieve rows
        while sqlite3_step(statement) == SQLITE_ROW {
            // Get the column values
            if let columnValue = sqlite3_column_text(statement, Int32(1)) {
                let val = String(cString:columnValue)
                if (val != "") {
                    rv.append(val)
                }
            }
            //let ts = sqlite3_column_int64(statement, Int32(2));
        }
        return rv;
    }
}
