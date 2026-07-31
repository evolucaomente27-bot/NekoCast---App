import sqlite3
import json

db_path = r'C:\Users\user\.local\share\mimocode\mimocode.db'
session_id = 'ses_0bbcb2163ffedMcBV5EuDhbFfm'

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get all parts from the APK session
    query = """
    SELECT id, message_id, json_extract(data, '$.type') as part_type, data
    FROM part 
    WHERE session_id = ? 
    ORDER BY time_created
    """
    
    cursor.execute(query, (session_id,))
    rows = cursor.fetchall()
    
    print(f"Total parts: {len(rows)}")
    for row in rows:
        part_id = row[0]
        msg_id = row[1]
        ptype = row[2]
        data_str = row[3]
        
        try:
            data = json.loads(data_str) if data_str else {}
        except:
            data = {}
        
        if ptype == 'tool':
            tool_name = data.get('tool', '?')
            state = data.get('state', {})
            inp = str(state.get('input', ''))[:300]
            out = str(state.get('output', ''))[:300]
            print(f"\n--- Tool: {tool_name} (msg: {msg_id}) ---")
            print(f"  Input: {inp}")
            print(f"  Output: {out}")
        elif ptype == 'text':
            text = data.get('text', '')[:500]
            print(f"\n--- Text (msg: {msg_id}) ---")
            print(f"  {text}")
        elif ptype in ('step-start', 'step-finish'):
            print(f"\n--- {ptype} (msg: {msg_id}) ---")
            if ptype == 'step-finish':
                tokens = data.get('tokens', {})
                print(f"  Tokens: {tokens}")
        else:
            print(f"\n--- {ptype} (msg: {msg_id}) ---")
            
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
finally:
    if conn:
        conn.close()
