#!/bin/bash
# Debug script for cron environment issues

LOG_FILE="/app/logs/debug_cron.log"

echo "=== CRON DEBUG REPORT $(date) ===" >> $LOG_FILE

echo "Environment Variables:" >> $LOG_FILE
env | sort >> $LOG_FILE

echo -e "\nPATH components:" >> $LOG_FILE
echo $PATH | tr ':' '\n' >> $LOG_FILE

echo -e "\nPython location and version:" >> $LOG_FILE
which python3 >> $LOG_FILE 2>&1
python3 --version >> $LOG_FILE 2>&1

echo -e "\nPython modules test:" >> $LOG_FILE
python3 -c "
import sys
print('Python executable:', sys.executable)
print('Python path:', sys.path)
try:
    import requests
    print('✅ requests module: OK')
except ImportError as e:
    print('❌ requests module:', e)

try:
    import feedparser
    print('✅ feedparser module: OK')
except ImportError as e:
    print('❌ feedparser module:', e)

try:
    import feedgen
    print('✅ feedgen module: OK')
except ImportError as e:
    print('❌ feedgen module:', e)
" >> $LOG_FILE 2>&1

echo -e "\nFile system check:" >> $LOG_FILE
echo "Working directory: $(pwd)" >> $LOG_FILE
echo "/app/scripts/ contents:" >> $LOG_FILE
ls -la /app/scripts/ >> $LOG_FILE 2>&1

echo -e "\nCrontab contents:" >> $LOG_FILE
crontab -l >> $LOG_FILE 2>&1

echo -e "\nActive processes:" >> $LOG_FILE
ps aux | grep -E "(cron|python)" >> $LOG_FILE

echo -e "\n=== END DEBUG REPORT ===\n" >> $LOG_FILE

# Also output to stdout for immediate viewing
cat $LOG_FILE | tail -50