import re
from datetime import datetime, timedelta

# Read the file
with open('/Users/james.ferguson/Documents/Financial/Tax/work_from_home_log.csv', 'r') as f:
    lines = f.readlines()

def parse_time(line):
    parts = line.strip().split(',')
    if len(parts) >= 2:
        dt_str = f"{parts[0]} {parts[1]}"
        return datetime.strptime(dt_str, '%Y-%m-%d %H:%M:%S')
    return None

result = []
i = 0
while i < len(lines):
    if i + 1 < len(lines):
        time1 = parse_time(lines[i])
        time2 = parse_time(lines[i+1])
        
        if time1 and time2:
            # Check if same time or 1 second apart
            diff = abs((time2 - time1).total_seconds())
            if diff <= 1:
                # Skip both lines
                i += 2
                continue
    
    # Keep this line
    result.append(lines[i])
    i += 1

# Write result
with open('/Users/james.ferguson/Documents/Financial/Tax/work_from_home_log_cleaned.csv', 'w') as f:
    f.writelines(result)

print(f"Original lines: {len(lines)}")
print(f"Cleaned lines: {len(result)}")
print(f"Removed: {len(lines) - len(result)}")
