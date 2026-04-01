#!/usr/bin/env bash
set -e

echo "🚀 Starting ${PODCAST_NAME:-Unknown} Feed container..."

# Dump the container's env so cron jobs inherit it
echo "🔧 Dumping environment variables to /etc/environment..."
printenv > /etc/environment

# IMPORTANT: Add Python path to cron environment
echo "🐍 Setting up Python environment for cron..."
echo "PATH=/usr/local/bin:/usr/bin:/bin:$PATH" >> /etc/environment
SITE_PACKAGES_PATH="$(python3 - <<'PY'
import sysconfig
print(sysconfig.get_paths()["purelib"])
PY
)"
echo "PYTHONPATH=${SITE_PACKAGES_PATH}" >> /etc/environment

# Set up root crontab for BusyBox crond
echo "⏰ Setting up crontab for ${PODCAST_NAME}..."
if [[ -f /app/scripts/crontab ]]; then
    mkdir -p /etc/crontabs
    cp /app/scripts/crontab /etc/crontabs/root
    chmod 600 /etc/crontabs/root
    echo "✅ Loaded crontab from /app/scripts/crontab"
else
    echo "❌ ERROR: Crontab file not found at /app/scripts/crontab"
    echo "Available files in /app/scripts/:"
    ls -la /app/scripts/
    exit 1
fi

# Show what's scheduled
echo "📅 Current crontab for ${PODCAST_NAME}:"
cat /etc/crontabs/root

# Create log directory if it doesn't exist
mkdir -p /app/logs

# Show environment info
echo "🔧 Environment:"
echo "   PODCAST_NAME: ${PODCAST_NAME:-Not set}"
echo "   FEED_NAME: ${FEED_NAME:-Not set}"
echo "   DOMAIN: ${DOMAIN:-Not set}"
echo "   Python version: $(python3 --version)"
echo "   Python path: $(which python3)"

# Test if Python modules are available
echo "🧪 Testing Python modules..."
python3 -c "import requests, feedparser; print('✅ All Python modules available')" || echo "❌ Python modules missing"

# Start cron in foreground
echo "🔄 Starting cron daemon for ${PODCAST_NAME}..."
exec crond -f -l 2
