#!/bin/bash
set -e

echo "🚀 Starting ${PODCAST_NAME:-Unknown} Feed container..."

# Install cron if not present
echo "📦 Installing cron..."
apt-get update && apt-get install -y cron

# Dump the container's env so cron jobs inherit it
echo "🔧 Dumping environment variables to /etc/environment..."
printenv > /etc/environment

# IMPORTANT: Add Python path to cron environment
echo "🐍 Setting up Python environment for cron..."
echo "PATH=/usr/local/bin:/usr/bin:/bin:$PATH" >> /etc/environment
echo "PYTHONPATH=/usr/local/lib/python3.11/site-packages" >> /etc/environment

# Set up crontab - use the podcast-specific crontab file
echo "⏰ Setting up crontab for ${PODCAST_NAME}..."
if [[ -f /app/scripts/crontab ]]; then
    # Source environment before setting crontab
    crontab /app/scripts/crontab
    echo "✅ Loaded crontab from /app/scripts/crontab"
else
    echo "❌ ERROR: Crontab file not found at /app/scripts/crontab"
    echo "Available files in /app/scripts/:"
    ls -la /app/scripts/
    exit 1
fi

# Show what's scheduled
echo "📅 Current crontab for ${PODCAST_NAME}:"
crontab -l

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
exec cron -f