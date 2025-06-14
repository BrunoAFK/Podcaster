#!/usr/bin/env bash

# Get podcast name from environment or default to "unknown"
PODCAST_NAME="${PODCAST_NAME:-unknown}"

# Check if telegram is configured
if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "⚠️ Telegram not configured - skipping notification"
    exit 0
fi

# Check if notifications are enabled
if [[ "${TELEGRAM_NOTIFICATIONS_ENABLED:-true}" != "true" ]]; then
    echo "🔇 Telegram notifications disabled - skipping"
    exit 0
fi

# Send notification
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "text=⚠️ ${PODCAST_NAME}_feed script failed at $(date '+%Y-%m-%d %H:%M:%S')" \
  -d "parse_mode=HTML" \
  --max-time 10

echo "📱 Failure notification sent for ${PODCAST_NAME}"