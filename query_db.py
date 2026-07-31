import sqlite3

db_path = r'C:\Users\user\.local\share\mimocode\mimocode.db'
session_id = 'ses_0bbcb2163ffedMcBV5EuDhbFfm'

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get text parts from the APK generation session
    query = """
    SELECT id, data 
    FROM part 
    WHERE session_id = ? 
    AND json_extract(data, '$.type') = 'text' 
    ORDER BY time_created
    """
    
    cursor.execute(query, (session_id,))
    rows = cursor.fetchall()
    
    print(f"Text parts found: {len(rows)}")
    for row in rows:
        print(f"Part ID: {row[0]}")
        print(f"Data preview: {str(row[1])[:800]}...")
        print("-" * 40)

except Exception as e:
    print(f"Error: {e}")
finally:
    if conn:
        conn.close()
