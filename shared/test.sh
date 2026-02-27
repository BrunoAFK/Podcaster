#!/bin/bash

# Complete test script za sve podcast URLove
DOMAIN="https://podcast.afk.place"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 COMPLETE PODCAST URL TEST for ${DOMAIN}${NC}\n"

# Function to test URL with both headers and content
test_url() {
    local url="$1"
    local description="$2"
    local expected_type="$3"
    local check_content="$4"
    
    echo -e "${YELLOW}━━━ Testing: ${description} ━━━${NC}"
    echo -e "🌐 URL: ${BLUE}${url}${NC}"
    
    # Get headers with timing info
    headers=$(curl -s -I -w "HTTPCODE:%{http_code}|SIZE:%{size_download}|TYPE:%{content_type}|TIME:%{time_total}" "$url" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        http_code=$(echo "$headers" | grep -o "HTTPCODE:[0-9]*" | cut -d: -f2)
        content_type=$(echo "$headers" | grep -o "TYPE:[^|]*" | cut -d: -f2)
        size=$(echo "$headers" | grep -o "SIZE:[^|]*" | cut -d: -f2)
        time=$(echo "$headers" | grep -o "TIME:[^|]*" | cut -d: -f2)
        
        if [[ "$http_code" == "200" ]]; then
            echo -e "📊 ${GREEN}✅ Status: $http_code${NC} | Type: $content_type | Size: ${size}B | Time: ${time}s"
            
            # Extract useful headers
            rate_limit=$(echo "$headers" | grep -i "x-rate-limit:" | cut -d: -f2- | tr -d '\r' || echo "None")
            cache_status=$(echo "$headers" | grep -i "x-cache-status:" | cut -d: -f2- | tr -d '\r' || echo "None")
            cache_control=$(echo "$headers" | grep -i "cache-control:" | cut -d: -f2- | tr -d '\r' || echo "None")
            
            echo -e "🚦 Rate Limit: ${rate_limit// /}"
            echo -e "💾 Cache Status: ${cache_status// /}"
            echo -e "⏰ Cache Control: ${cache_control// /}"
            
            # Test actual content if requested
            if [[ "$check_content" == "true" ]]; then
                echo -e "📄 ${PURPLE}Content Check:${NC}"
                content=$(curl -s "$url" 2>/dev/null)
                content_size=${#content}
                
                if [[ "$expected_type" == *"xml"* ]]; then
                    # Check XML validity
                    if echo "$content" | xmllint --noout - 2>/dev/null; then
                        echo -e "   ✅ Valid XML ($content_size chars)"
                        # Extract RSS title
                        title=$(echo "$content" | grep -o '<title>[^<]*</title>' | head -1 | sed 's/<[^>]*>//g' || echo "No title found")
                        echo -e "   📰 Title: ${title}"
                        # Count items
                        item_count=$(echo "$content" | grep -c '<item>' || echo "0")
                        echo -e "   📋 Episodes: ${item_count}"
                    else
                        echo -e "   ❌ Invalid XML"
                        echo -e "   🔍 First 200 chars: ${content:0:200}..."
                    fi
                elif [[ "$expected_type" == *"image"* ]]; then
                    # Check if it's actually an image
                    if [[ $content_size -gt 1000 ]]; then
                        echo -e "   ✅ Image file ($content_size bytes)"
                        # Check image magic bytes
                        magic=$(echo "$content" | head -c 10 | hexdump -C | head -1 || echo "No magic")
                        echo -e "   🔮 Magic bytes: ${magic}"
                    else
                        echo -e "   ⚠️  Suspiciously small image ($content_size bytes)"
                    fi
                else
                    # Plain text content
                    echo -e "   📝 Content ($content_size chars): ${content:0:100}..."
                fi
            fi
            
        elif [[ "$http_code" == "429" ]]; then
            echo -e "⚠️  ${YELLOW}Rate limited (429)${NC}"
        else
            echo -e "❌ ${RED}Failed: HTTP $http_code${NC}"
            # Get some error content
            error_content=$(curl -s "$url" 2>/dev/null | head -c 200)
            if [[ -n "$error_content" ]]; then
                echo -e "🔍 Error content: ${error_content}..."
            fi
        fi
    else
        echo -e "❌ ${RED}Connection failed${NC}"
    fi
    echo ""
}

#!/bin/bash

# COMPLETE PODCAST URL TEST - FIXED VERSION
DOMAIN="https://podcast.afk.place"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 COMPLETE PODCAST URL TEST for ${DOMAIN}${NC}"
echo -e "${YELLOW}⚡ FIXED VERSION - No hanging, with anti-rate-limit delays${NC}\n"

# Rate limit delay between requests
DELAY=3

# Function to test URL with both headers and content + anti-rate-limit delay
test_url() {
    local url="$1"
    local description="$2"
    local expected_type="$3"
    local check_content="$4"
    
    echo -e "${YELLOW}━━━ Testing: ${description} ━━━${NC}"
    echo -e "🌐 URL: ${BLUE}${url}${NC}"
    
    # Get headers with timing info
    headers=$(curl -s -I -w "HTTPCODE:%{http_code}|SIZE:%{size_download}|TYPE:%{content_type}|TIME:%{time_total}" "$url" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        http_code=$(echo "$headers" | grep -o "HTTPCODE:[0-9]*" | cut -d: -f2)
        content_type=$(echo "$headers" | grep -o "TYPE:[^|]*" | cut -d: -f2)
        size=$(echo "$headers" | grep -o "SIZE:[^|]*" | cut -d: -f2)
        time=$(echo "$headers" | grep -o "TIME:[^|]*" | cut -d: -f2)
        
        if [[ "$http_code" == "200" ]]; then
            echo -e "📊 ${GREEN}✅ Status: $http_code${NC} | Type: $content_type | Size: ${size}B | Time: ${time}s"
            
            # Extract useful headers
            rate_limit=$(echo "$headers" | grep -i "x-rate-limit:" | cut -d: -f2- | tr -d '\r' || echo "None")
            cache_status=$(echo "$headers" | grep -i "x-cache-status:" | cut -d: -f2- | tr -d '\r' || echo "None")
            cache_control=$(echo "$headers" | grep -i "cache-control:" | cut -d: -f2- | tr -d '\r' || echo "None")
            no_rate_limit=$(echo "$headers" | grep -i "x-no-rate-limit:" | cut -d: -f2- | tr -d '\r' || echo "None")
            
            echo -e "🚦 Rate Limit: ${rate_limit// /}"
            echo -e "💾 Cache Status: ${cache_status// /}"
            echo -e "⏰ Cache Control: ${cache_control// /}"
            echo -e "🔓 Rate Bypass: ${no_rate_limit// /}"
            
            # Test actual content if requested
            if [[ "$check_content" == "true" ]]; then
                echo -e "📄 ${PURPLE}Content Check:${NC}"
                content=$(curl -s "$url" 2>/dev/null)
                content_size=${#content}
                
                if [[ "$expected_type" == *"xml"* ]]; then
                    # Check XML validity
                    if echo "$content" | xmllint --noout - 2>/dev/null; then
                        echo -e "   ✅ Valid XML ($content_size chars)"
                        # Extract RSS title
                        title=$(echo "$content" | grep -o '<title>[^<]*</title>' | head -1 | sed 's/<[^>]*>//g' || echo "No title found")
                        echo -e "   📰 Title: ${title}"
                        # Count items
                        item_count=$(echo "$content" | grep -c '<item>' || echo "0")
                        echo -e "   📋 Episodes: ${item_count}"
                    else
                        echo -e "   ❌ Invalid XML"
                        echo -e "   🔍 First 200 chars: ${content:0:200}..."
                    fi
                elif [[ "$expected_type" == *"image"* ]]; then
                    # Check if it's actually an image
                    if [[ $content_size -gt 1000 ]]; then
                        echo -e "   ✅ Image file ($content_size bytes)"
                        # Check image magic bytes
                        magic=$(echo "$content" | head -c 10 | hexdump -C | head -1 || echo "No magic")
                        echo -e "   🔮 Magic bytes: ${magic}"
                    else
                        echo -e "   ⚠️  Suspiciously small image ($content_size bytes)"
                    fi
                else
                    # Plain text content
                    echo -e "   📝 Content ($content_size chars): ${content:0:100}..."
                fi
            fi
            
        elif [[ "$http_code" == "429" ]]; then
            echo -e "⚠️  ${YELLOW}Rate limited (429) - Increasing delay...${NC}"
            DELAY=$((DELAY + 2))  # Increase delay for next requests
        else
            echo -e "❌ ${RED}Failed: HTTP $http_code${NC}"
            # Get some error content
            error_content=$(curl -s "$url" 2>/dev/null | head -c 200)
            if [[ -n "$error_content" ]]; then
                echo -e "🔍 Error content: ${error_content}..."
            fi
        fi
    else
        echo -e "❌ ${RED}Connection failed${NC}"
    fi
    
    echo ""
    # Anti-rate-limit delay
    if [[ "$DELAY" -gt 0 ]]; then
        echo -e "⏳ Waiting ${DELAY}s to avoid rate limiting..."
        sleep $DELAY
    fi
}

# Test all RSS Feed URLs (with content validation)
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📡 TESTING RSS FEED URLs (Headers + Content)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

test_url "${DOMAIN}/" "Root endpoint" "text/plain" true
test_url "${DOMAIN}/jutarnja-kronika" "Jutarnja Kronika RSS (no slash)" "application/rss+xml" true
test_url "${DOMAIN}/jutarnja-kronika/" "Jutarnja Kronika RSS (WITH slash)" "application/rss+xml" true
test_url "${DOMAIN}/vijesti" "Vijesti RSS (no slash)" "application/rss+xml" true
test_url "${DOMAIN}/vijesti/" "Vijesti RSS (WITH slash)" "application/rss+xml" true

# Test all Artwork URLs
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🖼️  TESTING ARTWORK URLs (All combinations)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Jutarnja Kronika artwork
test_url "${DOMAIN}/jutarnja-kronika/jk.jpg" "JK artwork (legacy jk.jpg)" "image/jpeg" true
test_url "${DOMAIN}/jutarnja-kronika/jutarnja-kronika.jpg" "JK artwork (new jutarnja-kronika.jpg)" "image/jpeg" true
test_url "${DOMAIN}/jutarnja-kronika/artwork.jpg" "JK artwork (fallback artwork.jpg)" "image/jpeg" true

# Vijesti artwork
test_url "${DOMAIN}/vijesti/v.jpg" "Vijesti artwork (legacy v.jpg)" "image/jpeg" true
test_url "${DOMAIN}/vijesti/vijesti.jpg" "Vijesti artwork (new vijesti.jpg)" "image/jpeg" true
test_url "${DOMAIN}/vijesti/artwork.jpg" "Vijesti artwork (fallback artwork.jpg)" "image/jpeg" true

# Test Utility Endpoints
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🛠️  TESTING UTILITY ENDPOINTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

test_url "${DOMAIN}/health" "Health check" "text/plain" true
test_url "${DOMAIN}/cache-info" "Cache info" "text/plain" true
test_url "${DOMAIN}/rate-limit-status" "Rate limit status" "text/plain" true

# Test non-existent URLs (should return 404 or redirect)
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🚫 TESTING NON-EXISTENT URLs (Should fail)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

test_url "${DOMAIN}/nonexistent" "Non-existent endpoint" "text/html" false
test_url "${DOMAIN}/jutarnja-kronika/nonexistent.jpg" "Non-existent JK image" "text/html" false
test_url "${DOMAIN}/vijesti/nonexistent.xml" "Non-existent Vijesti file" "text/html" false

# Function to test file existence inside container
test_file_existence() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔍 CHECKING FILE EXISTENCE INSIDE NGINX CONTAINER${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
    
    files=(
        "/usr/share/nginx/html/jutarnja-kronika/jk.xml:JK RSS feed file"
        "/usr/share/nginx/html/jutarnja-kronika/jutarnja-kronika.jpg:JK new artwork"
        "/usr/share/nginx/html/jutarnja-kronika/jk.jpg:JK legacy artwork (should NOT exist)"
        "/usr/share/nginx/html/vijesti/v.xml:Vijesti RSS feed file"
        "/usr/share/nginx/html/vijesti/vijesti.jpg:Vijesti new artwork"
        "/usr/share/nginx/html/vijesti/v.jpg:Vijesti legacy artwork (should NOT exist)"
        "/usr/share/nginx/html/jk.jpg:Root level JK artwork (legacy)"
        "/usr/share/nginx/html/v.jpg:Root level Vijesti artwork (legacy)"
    )
    
    for file_info in "${files[@]}"; do
        file_path="${file_info%%:*}"
        description="${file_info##*:}"
        
        echo -e "${YELLOW}🔍 Checking: ${description}${NC}"
        echo -e "📁 Path: ${file_path}"
        
        # Check if file exists and get detailed info
        if docker compose exec -T web test -f "$file_path" 2>/dev/null; then
            file_details=$(docker compose exec -T web ls -la "$file_path" 2>/dev/null)
            file_size=$(docker compose exec -T web stat -c%s "$file_path" 2>/dev/null)
            echo -e "✅ ${GREEN}EXISTS${NC} - Size: ${file_size} bytes"
            echo -e "📋 Details: ${file_details}"
            
            # Additional checks for specific file types
            if [[ "$file_path" == *".xml" ]]; then
                # Check if XML is valid
                if docker compose exec -T web xmllint --noout "$file_path" 2>/dev/null; then
                    echo -e "✅ Valid XML format"
                else
                    echo -e "❌ Invalid XML format"
                fi
            elif [[ "$file_path" == *".jpg" ]]; then
                # Check if it's a real image (basic check)
                magic=$(docker compose exec -T web file "$file_path" 2>/dev/null || echo "Unknown file type")
                echo -e "🔮 File type: ${magic}"
            fi
        else
            echo -e "❌ ${RED}NOT FOUND${NC}"
        fi
        echo ""
    done
}

# Execute file existence check
test_file_existence

# Nginx diagnostics - FIXED VERSION (uses docker logs instead of files)
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔧 NGINX DIAGNOSTICS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}🔍 Nginx Configuration Syntax Check:${NC}"
if docker compose exec -T web nginx -t 2>/dev/null; then
    echo -e "${GREEN}✅ Nginx config syntax is VALID${NC}"
else
    echo -e "${RED}❌ Nginx config has SYNTAX ERRORS${NC}"
    docker compose exec -T web nginx -t 2>&1 | head -20
fi

echo -e "\n${YELLOW}🔍 Nginx Process Status:${NC}"
nginx_processes=$(docker compose exec -T web ps aux | grep nginx | grep -v grep || echo "No nginx processes found")
echo "$nginx_processes"

# FIXED: Use docker logs instead of log files (they're symlinked to stdout/stderr)
echo -e "\n${YELLOW}🔍 Nginx Docker Logs (last 15 lines):${NC}"
docker_logs=$(docker compose logs --tail=15 web 2>/dev/null | grep -E "(GET|POST|PUT|DELETE|HEAD|error|warn|nginx)" || echo "No recent nginx logs found")
if [[ -n "$docker_logs" ]]; then
    echo "$docker_logs"
else
    echo "No relevant nginx logs in recent Docker output"
fi

echo -e "\n${YELLOW}🔍 Live Docker Log Test:${NC}"
echo "Generating a test request to see live logging..."
curl -s -I "${DOMAIN}/health" >/dev/null &
sleep 2
recent_logs=$(docker compose logs --tail=5 web 2>/dev/null | grep -E "(GET|HEAD)" | tail -2 || echo "No new logs captured")
echo "$recent_logs"

echo -e "\n${YELLOW}🔍 Active Nginx Configuration (relevant parts):${NC}"
echo -e "${PURPLE}Checking location blocks for jutarnja-kronika:${NC}"
docker compose exec -T web grep -A 3 -B 1 "jutarnja-kronika" /etc/nginx/conf.d/default.conf || echo "No jutarnja-kronika config found"

echo -e "\n${PURPLE}Checking location blocks for vijesti:${NC}"
docker compose exec -T web grep -A 3 -B 1 "vijesti" /etc/nginx/conf.d/default.conf || echo "No vijesti config found"

echo -e "\n${PURPLE}Checking rate limiting configuration:${NC}"
docker compose exec -T web grep -A 1 -B 1 "limit_req" /etc/nginx/conf.d/default.conf | head -10 || echo "No rate limiting config found"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🏁 COMPLETE TEST FINISHED!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Summary
echo -e "\n${YELLOW}📋 QUICK SUMMARY:${NC}"
echo -e "🔗 Main URLs tested:"
echo -e "   • ${DOMAIN}/jutarnja-kronika"
echo -e "   • ${DOMAIN}/jutarnja-kronika/ ${RED}← CHECK IF THIS WORKED${NC}"
echo -e "   • ${DOMAIN}/vijesti"
echo -e "   • ${DOMAIN}/vijesti/ ${RED}← CHECK IF THIS WORKED${NC}"
echo -e "   • ${DOMAIN}/jutarnja-kronika/jutarnja-kronika.jpg"
echo -e "   • ${DOMAIN}/vijesti/vijesti.jpg"
echo -e "\n${GREEN}💡 If trailing slash URLs still fail, nginx location config needs fixing!${NC}"