#!/usr/bin/env python3
import os, json, re, sys, pathlib, logging, traceback, time
from datetime import datetime, timezone
from logging.handlers import TimedRotatingFileHandler
import requests, feedparser
from dateutil import parser as date_parse
from feedgen.feed import FeedGenerator
from zoneinfo import ZoneInfo

# Basic configuration
DOMAIN = os.environ.get('DOMAIN', 'localhost')
FEED_NAME = os.environ.get('FEED_NAME', 'v')  # ← MOVED UP: Define before using
PODCAST_NAME = os.environ.get('PODCAST_NAME', 'unknown')
PATH_MAP = {'v': 'vijesti'}  # Updated for Vijesti
MAX_EPISODES = int(os.environ.get('MAX_EPISODES', '30'))
CRO_TZ = ZoneInfo("Europe/Zagreb")

# URLs and paths
BASE_URL = 'https://radio.hrt.hr/slusaonica/vijesti'
PODCAST_SLUG = PATH_MAP.get(FEED_NAME, FEED_NAME)  # Now FEED_NAME is defined
SAVE_DIR = pathlib.Path(__file__).resolve().parent.parent / 'feeds' / PODCAST_SLUG
FEED_FILE = SAVE_DIR / f"{FEED_NAME}.xml"
PUBLIC_URL = f"https://{DOMAIN}/{PODCAST_SLUG}"  # Use PODCAST_SLUG instead of PATH_MAP lookup

# Telegram settings
TELEGRAM_BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.environ.get('TELEGRAM_CHAT_ID')
TELEGRAM_NOTIFICATIONS_ENABLED = os.environ.get('TELEGRAM_NOTIFICATIONS_ENABLED', 'true').lower() == 'true'
TELEGRAM_NOTIFICATION_TYPES = os.environ.get('TELEGRAM_NOTIFICATION_TYPES', 'all').lower().split(',')

# Create directory structure
SAVE_DIR.mkdir(parents=True, exist_ok=True)

# Enhanced logger - store logs in the main feeds directory, not in subfolder
log = logging.getLogger(PODCAST_NAME)
log.setLevel(logging.INFO)
log_file_path = SAVE_DIR.parent / f'{PODCAST_NAME}.log'  # Store in /feeds/ not /feeds/vijesti/
h = TimedRotatingFileHandler(log_file_path, when='midnight',
                             backupCount=7, encoding='utf-8')
h.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s',
                                 '%Y-%m-%d %H:%M:%S'))
log.addHandler(h)

def send_telegram_notification(message, is_error=False):
    """Send notification to Telegram with enhanced control"""
    
    if not TELEGRAM_NOTIFICATIONS_ENABLED:
        return
    
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    
    msg_type = 'error' if is_error else 'success'
    
    if 'all' not in TELEGRAM_NOTIFICATION_TYPES and msg_type not in TELEGRAM_NOTIFICATION_TYPES:
        return
    
    try:
        feed_display_name = FEED_NAME.upper()  # v → V
        if is_error:
            emoji = "🚨"
            full_message = f"{emoji} <b>{feed_display_name} Feed Error</b>\n❌ {message}"
        else:
            emoji = "📻"
            full_message = f"{emoji} <b>{feed_display_name} Feed</b>\n✅ {message}"
        
        response = requests.post(
            f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage',
            data={
                'chat_id': TELEGRAM_CHAT_ID,
                'text': full_message,
                'parse_mode': 'HTML'
            },
            timeout=10
        )
        response.raise_for_status()
        log.info(f"Telegram notification sent: {msg_type}")
    except Exception as e:
        log.error(f"Failed to send Telegram notification: {e}")

def send_telegram_info(message):
    """Send info notification to Telegram"""
    
    if not TELEGRAM_NOTIFICATIONS_ENABLED:
        return
    
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    
    if 'all' not in TELEGRAM_NOTIFICATION_TYPES and 'info' not in TELEGRAM_NOTIFICATION_TYPES:
        return
    
    try:
        feed_display_name = FEED_NAME.upper()  
        full_message = f"ℹ️ <b>{feed_display_name} Feed Info</b>\n{message}"
        
        response = requests.post(
            f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage',
            data={
                'chat_id': TELEGRAM_CHAT_ID,
                'text': full_message,
                'parse_mode': 'HTML'
            },
            timeout=10
        )
        response.raise_for_status()
        log.info("Telegram info notification sent")
    except Exception as e:
        log.error(f"Failed to send Telegram info notification: {e}")

def fetch_html():
    """Fetch HTML with retry logic"""
    headers = {'User-Agent': 'Mozilla/5.0 (compatible; PodcastBot/1.0)'}
    
    for attempt in range(3):
        try:
            response = requests.get(BASE_URL, headers=headers, timeout=15)
            response.raise_for_status()
            return response.text
        except requests.RequestException as e:
            log.warning(f"Attempt {attempt + 1} failed: {e}")
            if attempt == 2:  # Last attempt
                raise
            time.sleep(5)  # Wait before retry

def parse_next(html):
    """Parse episode data from HTML"""
    try:
        match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
        if not match:
            raise ValueError("Could not find __NEXT_DATA__ script tag")
        
        data = json.loads(match.group(1))
        
        # Navigate the data structure safely
        episodes_data = data.get('props', {}).get('pageProps', {}).get('episodes', {}).get('data', {})
        episodes = episodes_data.get('lastAvailableEpisodes', [])
        
        if not episodes:
            raise ValueError("No episodes found in data")
        parsed = [ep for ep in (parse_episode(e) for e in episodes) if ep]
        if not parsed:
            raise ValueError("No parseable episodes found")
        mp3, title, desc, dt = max(parsed, key=lambda item: item[3].timestamp())
        return mp3, title, desc, dt
        
    except (json.JSONDecodeError, KeyError, IndexError, ValueError) as e:
        raise ValueError(f"Failed to parse episode data: {e}")

def parse_episode(ep):
    audio_metadata = ep.get('audio', {}).get('metadata', [])
    if not audio_metadata:
        return None
    mp3 = audio_metadata[0].get('path')
    if not mp3:
        return None
    title = ep.get('caption', 'Untitled Episode')
    desc = ep.get('intro', '')
    dt = extract_episode_datetime(ep, mp3)
    return mp3, title, desc, dt

def extract_episode_datetime(ep, mp3):
    bag_items = ep.get('bag', {}).get('contentItems', [])
    if bag_items:
        broadcast_start = bag_items[0].get('broadcastStart')
        if broadcast_start:
            dt = date_parse.parse(broadcast_start)
            if dt.tzinfo is None:
                return dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc)
    match = re.search(r'(20\d{12})', mp3 or '')
    if match:
        return datetime.strptime(match.group(1), "%Y%m%d%H%M%S").replace(tzinfo=timezone.utc)
    return datetime.now(timezone.utc)

def latest_id():
    """Get the ID of the latest episode in feed"""
    if FEED_FILE.exists():
        try:
            feed = feedparser.parse(FEED_FILE)
            if feed.entries:
                return feed.entries[0].id
        except Exception as e:
            log.warning(f"Could not parse existing feed: {e}")
    return None

def format_title(title, dt):
    """Format episode title with local (Croatia) time."""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    local_time = dt.astimezone(CRO_TZ).strftime('%H:%M')
    return f"{title} - {local_time}"

def update(mp3, title, desc, dt):
    """Update feed with new episode"""
    # Check if this episode already exists
    existing_entries = []
    if FEED_FILE.exists():
        try:
            existing_feed = feedparser.parse(FEED_FILE)
            existing_entries = existing_feed.entries
            # Check if this mp3 URL already exists
            if any(entry.id == mp3 for entry in existing_entries):
                log.info(f"Episode already exists: {title}")
                return False  # No update needed
        except Exception as e:
            log.warning(f"Could not read existing feed: {e}")
    
    try:
        # Create new feed generator
        fg = FeedGenerator()
        fg.load_extension('podcast')
        
        # Set feed metadata
        fg.title('Vijesti (Neslužbeno)')
        fg.link(href=PUBLIC_URL, rel='self')
        fg.description('Neslužbena RSS distribucija emisije Vijesti (HRT). Petominutna informativna emisija, svaki puni sat prati sve relevantne događaje u zemlji i inozemstvu.')
        fg.language('hr')
        fg.copyright('© Sadržaj: HRT | RSS distribucija: HRT')
        fg.category({'term': 'News', 'label': 'News'})
        
        # Artwork path - use logical naming (vijesti.jpg, not v.jpg)
        artwork_filename = f"{PODCAST_SLUG}.jpg"  # vijesti.jpg
        fg.image(f"{PUBLIC_URL}/{artwork_filename}", 'Vijesti', PUBLIC_URL)
        
        # Set podcast-specific metadata
        fg.podcast.itunes_author('HRT (Neslužbeno)')
        fg.podcast.itunes_category('News')
        fg.podcast.itunes_explicit('no')
        fg.podcast.itunes_summary('Neslužbena RSS distribucija emisije Vijesti. Sadržaj je vlasništvo HRT-a, distribucija je neslužbena.')
        fg.podcast.itunes_image(f"{PUBLIC_URL}/{artwork_filename}")
        
        # Add new episode first
        fe = fg.add_entry()
        fe.id(mp3)
        fe.title(f"{format_title(title, dt)} (HRT)")
        fe.description(f"{desc}\n\n---\nSadržaj: © HRT | Neslužbena RSS distribucija")
        fe.enclosure(mp3, 0, 'audio/mpeg')
        fe.pubDate(dt.astimezone(CRO_TZ))  # Use Croatian timezone
        fe.podcast.itunes_author('HRT')
        fe.podcast.itunes_explicit('no')

        # Sort existing entries by date (newest first) and limit episodes
        sorted_entries = sorted(
            existing_entries[:MAX_EPISODES-1],
            key=lambda e: date_parse.parse(e.published).timestamp(),
            reverse=True
        )
        for entry in sorted_entries:
            fe = fg.add_entry()
            fe.id(entry.id)
            fe.title(entry.title)
            fe.description(entry.get('description', ''))
            fe.enclosure(entry.enclosures[0].href if entry.enclosures else entry.id, 0, 'audio/mpeg')
            entry_dt = date_parse.parse(entry.published)
            fe.pubDate(entry_dt.astimezone(CRO_TZ))  # Use Croatian timezone
            fe.podcast.itunes_author('HRT')
            fe.podcast.itunes_explicit('no')

        # Reverse entries to ensure newest-first order (feedgen sorts by pubDate ascending)
        fg._FeedGenerator__feed_entries.reverse()

        # Write the feed
        fg.rss_file(str(FEED_FILE), pretty=True)
        log.info(f'Added new episode: {title}')
        return True  # Successfully updated
        
    except Exception as e:
        raise Exception(f"Failed to generate feed: {e}")

def parse_all_episodes(html):
    """Parse all available episodes from HTML"""
    try:
        match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
        if not match:
            raise ValueError("Could not find __NEXT_DATA__ script tag")
        
        data = json.loads(match.group(1))
        
        # Navigate the data structure safely
        episodes_data = data.get('props', {}).get('pageProps', {}).get('episodes', {}).get('data', {})
        episodes = episodes_data.get('lastAvailableEpisodes', [])
        
        if not episodes:
            raise ValueError("No episodes found in data")
        
        parsed_episodes = []
        for ep in episodes:
            try:
                parsed = parse_episode(ep)
                if parsed:
                    parsed_episodes.append(parsed)
            except Exception as e:
                log.warning(f"Failed to parse episode: {e}")
                continue
        return parsed_episodes
        
    except (json.JSONDecodeError, KeyError, IndexError, ValueError) as e:
        raise ValueError(f"Failed to parse episodes data: {e}")

def update_with_all_episodes(episodes):
    """Update feed with all provided episodes"""
    if not episodes:
        log.warning("No episodes provided for update")
        return False
    
    try:
        # Create new feed generator
        fg = FeedGenerator()
        fg.load_extension('podcast')
        
        # Set feed metadata
        fg.title('Vijesti (Neslužbeno)')
        fg.link(href=PUBLIC_URL, rel='self')
        fg.description('Neslužbena RSS distribucija emisije Vijesti (HRT). Petominutna informativna emisija, svaki puni sat prati sve relevantne događaje u zemlji i inozemstvu.')
        fg.language('hr')
        fg.copyright('© Sadržaj: HRT | RSS distribucija: HRT')
        fg.category({'term': 'News', 'label': 'News'})
        
        # Artwork path
        artwork_filename = f"{PODCAST_SLUG}.jpg"  # vijesti.jpg
        fg.image(f"{PUBLIC_URL}/{artwork_filename}", 'Vijesti', PUBLIC_URL)
        
        # Set podcast-specific metadata
        fg.podcast.itunes_author('HRT (Neslužbeno)')
        fg.podcast.itunes_category('News')
        fg.podcast.itunes_explicit('no')
        fg.podcast.itunes_summary('Neslužbena RSS distribucija emisije Vijesti. Sadržaj je vlasništvo HRT-a, distribucija je neslužbena.')
        fg.podcast.itunes_image(f"{PUBLIC_URL}/{artwork_filename}")
        
        # Sort episodes by date (newest first)
        episodes.sort(key=lambda x: x[3].timestamp(), reverse=True)

        # Limit episodes if needed
        episodes_to_add = episodes[:MAX_EPISODES]

        # Add all episodes
        for mp3, title, desc, dt in episodes_to_add:
            fe = fg.add_entry()
            fe.id(mp3)
            fe.title(f"{format_title(title, dt)} (HRT)")
            fe.description(f"{desc}\n\n---\nSadržaj: © HRT | Neslužbena RSS distribucija")
            fe.enclosure(mp3, 0, 'audio/mpeg')
            fe.pubDate(dt.astimezone(CRO_TZ))  # Use Croatian timezone
            fe.podcast.itunes_author('HRT')
            fe.podcast.itunes_explicit('no')
        
        # Reverse entries to ensure newest-first order (feedgen sorts by pubDate ascending)
        fg._FeedGenerator__feed_entries.reverse()

        # Write the feed
        fg.rss_file(str(FEED_FILE), pretty=True)
        log.info(f'Updated feed with {len(episodes_to_add)} episodes')
        return True

    except Exception as e:
        raise Exception(f"Failed to generate feed: {e}")

def main():
    """Main execution function"""
    import argparse
    
    feed_display_name = FEED_NAME.upper()  # v → V
    parser = argparse.ArgumentParser(description=f'{feed_display_name} Feed Generator')
    parser.add_argument('--fetch-all', action='store_true', 
                       help='Fetch all available episodes instead of just checking for new ones')
    parser.add_argument('--quiet', action='store_true',
                       help='Suppress Telegram notifications (useful for manual runs)')
    
    args = parser.parse_args()
    
    # Override telegram notifications if quiet mode
    global send_telegram_notification
    if args.quiet:
        def send_telegram_notification(message, is_error=False):
            pass  # Do nothing
    
    try:
        if args.fetch_all:
            log.info("Starting full episode fetch...")
            html = fetch_html()
            episodes = parse_all_episodes(html)
            
            log.info(f"Found {len(episodes)} episodes on the website")
            
            if episodes:
                updated = update_with_all_episodes(episodes)
                if updated:
                    send_telegram_notification(f"Feed refreshed with {len(episodes)} episodes")
                    log.info("Feed updated with all episodes successfully")
                else:
                    log.info("Failed to update feed")
            else:
                log.warning("No episodes found to add")
        else:
            log.info("Starting feed update check...")
            
            # Fetch and parse data
            html = fetch_html()
            mp3, title, desc, dt = parse_next(html)
            
            log.info(f"Found episode: {title}")
            
            # Check if update is needed
            current_latest = latest_id()
            if mp3 != current_latest:
                updated = update(mp3, title, desc, dt)
                if updated:
                    send_telegram_notification(f"New episode added: {title}")
                    log.info("Feed updated successfully")
                else:
                    log.info("Episode already exists, no update needed")
            else:
                log.info("No new episodes found")
            
    except Exception as e:
        error_msg = f"Script failed: {str(e)}"
        log.error(error_msg)
        log.error(f"Traceback: {traceback.format_exc()}")
        send_telegram_notification(error_msg, is_error=True)
        sys.exit(1)

if __name__ == '__main__':
    main()
