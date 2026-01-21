#!/usr/bin/env bash
set -e

: "${FEEDS:?FEEDS env var not set}"
: "${DOMAIN:=_}"

HTML_MOUNT=/usr/share/nginx/html

# Create main nginx config
cat > /etc/nginx/conf.d/default.conf << 'MAIN_CONFIG'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;
    root HTML_MOUNT_PLACEHOLDER;
    index off;
    add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
    add_header Pragma "no-cache" always;
    add_header Expires "0" always;

    location = / {
        try_files /index.html =404;
        add_header X-Served-By $hostname;
    }
MAIN_CONFIG

# Replace placeholders
sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" /etc/nginx/conf.d/default.conf
sed -i "s|HTML_MOUNT_PLACEHOLDER|${HTML_MOUNT}|g" /etc/nginx/conf.d/default.conf

# Process each feed
IFS=',' read -ra PAIRS <<< "$FEEDS"
for pair in "${PAIRS[@]}"; do
    slug="${pair%%:*}"
    xmlfile="${pair##*:}"
    jpgfile="${xmlfile%.xml}.jpg"
    actual_jpgfile="${slug}.jpg"
    feed_dir="${HTML_MOUNT}/${slug}"

    if [ ! -d "${feed_dir}" ]; then
        echo "⚠️  Warning: feed directory ${feed_dir} does not exist for ${slug}"
        continue
    fi
    
    echo "✅ Found feed directory for ${slug}: ${feed_dir}"
    echo "📁 XML file: ${xmlfile}"
    echo "🖼️  Expected artwork: ${actual_jpgfile}"

    # Add locations for this feed
    cat >> /etc/nginx/conf.d/default.conf << FEED_BLOCK

    # ${slug} RSS with trailing slash redirect
    location = /${slug}/ {
        return 301 /${slug};
    }

    # ${slug} RSS main endpoint
    location = /${slug} {
        alias ${feed_dir}/${xmlfile};
        default_type application/rss+xml;
        add_header X-Cache-Status "NGINX-RSS";
        add_header X-Feed-File "${xmlfile}";
    }

    # ${slug} artwork - primary
    location = /${slug}/${actual_jpgfile} {
        alias ${feed_dir}/${actual_jpgfile};
        add_header X-Cache-Status "NGINX-IMG-PRIMARY";
    }

    # ${slug} artwork - legacy
    location = /${slug}/${jpgfile} {
        alias ${feed_dir}/${actual_jpgfile};
        add_header X-Cache-Status "NGINX-IMG-LEGACY";
    }

    # ${slug} artwork - fallback
    location = /${slug}/artwork.jpg {
        alias ${feed_dir}/${actual_jpgfile};
        add_header X-Cache-Status "NGINX-IMG-FALLBACK";
    }
FEED_BLOCK

done

# Add utility endpoints
cat >> /etc/nginx/conf.d/default.conf << 'UTIL_ENDPOINTS'

    # Utility endpoints
    location = /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
        access_log off;
    }

    location = /cache-info {
        return 200 "Cache info: $time_iso8601\nServer: $hostname\n";
        add_header Content-Type text/plain;
    }

    location = /rate-limit-status {
        return 200 "No rate limiting configured.\n";
        add_header Content-Type text/plain;
    }

    location = /debug-files {
        return 200 "HTML Mount: HTML_MOUNT_PLACEHOLDER\n";
        add_header Content-Type text/plain;
    }
}
UTIL_ENDPOINTS

# Replace placeholder in utility endpoints
sed -i "s|HTML_MOUNT_PLACEHOLDER|${HTML_MOUNT}|g" /etc/nginx/conf.d/default.conf

echo "✅ nginx.conf generated successfully with redirect-based trailing slash handling"
echo "🔧 Applied fixes:"
echo "   - Clean heredoc structure to avoid syntax errors"
echo "   - 301 redirects for trailing slash URLs"
echo "   - Fixed artwork file aliases"
echo "   - Debug headers for troubleshooting"
