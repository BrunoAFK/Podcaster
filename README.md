# Podcaster

[![Daily Feed Validation](https://github.com/BrunoAFK/Podcaster/actions/workflows/daily-scraper-test.yml/badge.svg)](https://github.com/BrunoAFK/Podcaster/actions/workflows/daily-scraper-test.yml)

Automated RSS feed generator for Croatian Radio shows not available in podcast apps.

<br>

<div align="center">

### **[podcast.pavelja.me](https://podcast.pavelja.me)**

</div>

<br>

---

## Feeds

| Show | Schedule | Subscribe |
|------|----------|-----------|
| **Vijesti** | Every hour | [`podcast.pavelja.me/vijesti`](https://podcast.pavelja.me/vijesti) |
| **Jutarnja kronika** | Weekday mornings | [`podcast.pavelja.me/jutarnja-kronika`](https://podcast.pavelja.me/jutarnja-kronika) |

---

## How It Works

```
HRT Website ──> Scraper (Python) ──> RSS Feed (XML) ──> Your Podcast App
                    │
                    └── runs every 5 minutes via cron
```

1. Scraper fetches episode data from HRT
2. Generates standard RSS/podcast XML
3. Nginx serves feeds
4. Subscribe in any podcast app

---

## Self-Hosting

### Prerequisites

- Docker & Docker Compose
- (Optional) Telegram Bot for notifications

### Setup

```bash
# Clone
git clone https://github.com/BrunoAFK/Podcaster.git
cd Podcaster

# Configure
cp .env.example .env
vim .env

# Run
docker compose up -d
```

### Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `localhost` |
| `HOST_PORT` | Nginx port | `8080` |
| `FEEDS` | Feed mappings | `jutarnja-kronika:jk.xml,vijesti:v.xml` |
| `MAX_EPISODES` | Episodes to keep | `30` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot | — |
| `TELEGRAM_CHAT_ID` | Chat ID | — |

### Commands

```bash
# View logs
docker compose logs -f jk_feed

# Manual fetch
docker compose run --rm v_feed /app/shared/run.sh --fetch-all

# Restart
docker compose restart
```

---

## Project Structure

```
├── compose.yaml        # Docker services
├── Dockerfile          # Python container
├── nginx.conf          # Web server
├── feeds/              # Generated RSS + landing page
├── scripts_jk/         # Jutarnja kronika scraper
├── scripts_v/          # Vijesti scraper
├── shared/             # Shared scripts
└── logs/               # Application logs
```

---

## Stack

- **Python** — Scraping & RSS generation (feedgen, requests, beautifulsoup4)
- **Docker** — Containerized services
- **Nginx** — Static file serving
- **Cron** — Scheduled execution
- **Telegram** — Notifications (optional)

---

## License

MIT

---

<sub>Unofficial RSS distribution. Audio content belongs to respective broadcasters.</sub>
