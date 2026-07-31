import sqlite3

db_path = r'C:\Users\user\.local\share\mimocode\mimocode.db'

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get project_id for NekoCast sessions
    query = "SELECT id, project_id, directory, title FROM session WHERE directory LIKE ?"
    cursor.execute(query, ('%NekoCast%',))
    rows = cursor.fetchall()
    
    print(f"NekoCast sessions: {len(rows)}")
    for row in rows:
        print(f"Session: {row[0]}, Project: {row[1]}, Dir: {row[2]}, Title: {row[3]}")
        
except Exception as e:
    print(f"Error: {e}")
finally:
    if conn:
        conn.close()
