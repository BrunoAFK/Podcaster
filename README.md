# 🎙️ Croatian Radio Podcast Feed Generator

[![🗓️ Daily Scraper Feed Validation](https://github.com/BrunoAFK/Podcaster/actions/workflows/daily-scraper-test.yml/badge.svg)](https://github.com/BrunoAFK/Podcaster/actions/workflows/daily-scraper-test.yml)

A sophisticated Docker-based system that scrapes Croatian Radio websites and generates RSS podcast feeds for easy consumption in podcast apps.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Adding New Podcasts](#adding-new-podcasts)
- [Scripts Explained](#scripts-explained)
- [Telegram Notifications](#telegram-notifications)
- [Troubleshooting](#troubleshooting)
- [API Endpoints](#api-endpoints)
- [Development](#development)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## 🎯 Overview

This system automatically:
- **Scrapes** Croatian Radio websites for new episodes  
- **Generates** RSS feeds with proper podcast metadata  
- **Serves** feeds via Nginx with caching  
- **Monitors** for new episodes via cron jobs  
- **Notifies** via Telegram when new episodes are found  
- **Supports** multiple radio shows simultaneously  

Currently supported shows:
- **Jutarnja kronika** (Morning Chronicle) – HRT’s main morning news show  
- **Vijesti** (News) – HRT’s primary news broadcasts  

## ✨ Features

- 🐳 **Docker-based** – Easy deployment and scaling  
- 🔄 **Automated scraping** – Cron-based episode detection  
- 📱 **Telegram notifications** – Real-time alerts for new episodes  
- 🎨 **Individual artwork** – Each podcast has its own cover art  
- ⚙️ **Configurable** – Episode limits, notification types, schedules  
- 🔧 **Modular design** – Easy to add new radio shows  
- 📊 **Comprehensive logging** – Detailed logs for monitoring  
- 🚀 **High availability** – Automatic restarts and error handling  

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx Proxy   │    │  JK Feed Scraper │    │ Telegram Bot API │
│                 │    │                 │    │                 │
│ - Serves feeds  │    │ - Scrapes HRT   │    │ - Notifications │
│ - Caches files  │    │ - Generates RSS │    │ - Error alerts  │
│ - Static assets │    │ - Cron schedule │    │ - Status updates│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────┬───────────┴───────────┬───────────┘
                     │                       │
            ┌─────────────────┐     ┌─────────────────┐
            │ Shared Storage  │     │    Feeds Dir    │
            └─────────────────┘     └─────────────────┘
```

## 🗂️ Project Structure

```
.
├── Dockerfile
├── compose.yaml
├── nginx.conf
├── shared/               # shared scripts (render-conf, run, cron, etc.)
├── scripts_jk/           # Jutarnja kronika service
├── scripts_v/            # Vijesti service
├── feeds/                # generated RSS XMLs
├── logs/                 # application logs
└── .env                  # configuration
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose  
- Access to the Croatian Radio websites  
- (Optional) a Telegram Bot for notifications  

### 1. Clone & configure

```bash
git clone <repository-url>
cd PodcasterFeed
# edit the .env file with your settings
```

### 2. Build & start

```bash
# Build all services
docker compose build

# Start in detached mode
docker compose up -d
```

### 3. Check logs

```bash
# Follow the JK feed logs
docker compose logs -f jk_feed

# Follow the V feed logs
docker compose logs -f v_feed
```

### 4. Access Your Feeds

- **Jutarnja kronika**: `https://yourdomain.com/jutarnja-kronika`  
- **Vijesti**:         `https://yourdomain.com/vijesti`  
- **Artwork**:         `https://yourdomain.com/<feed>/artwork.jpg`  
- **Status**:          `https://yourdomain.com/` (returns “podcast host”)

## ⚙️ Configuration

### Environment Variables

| Variable                         | Description                       | Default     | Required |
|----------------------------------|-----------------------------------|-------------|----------|
| `DOMAIN`                         | Your domain name                  | `localhost` | ✅       |
| `HOST_PORT`                      | Nginx port                        | `8080`      | ❌       |
| `FEEDS`                          | Podcast mappings (slug:xml-name)  | —           | ✅       |
| `TELEGRAM_BOT_TOKEN`             | Telegram bot token                | —           | ❌       |
| `TELEGRAM_CHAT_ID`               | Telegram chat ID                  | —           | ❌       |
| `TELEGRAM_NOTIFICATIONS_ENABLED` | Enable/disable notifications      | `true`      | ❌       |
| `TELEGRAM_NOTIFICATION_TYPES`    | Notification types (`all`,`error`, etc.) | `all` | ❌ |
| `MAX_EPISODES`                   | Number of episodes to keep        | `30`        | ❌       |
| `LOG_RETENTION_DAYS`             | Log files retention (days)        | `7`         | ❌       |

#### Notification Types

- **`all`** – All notifications (default)  
- **`success`**, **`error`**, **`info`** – Filter by type  

#### Manual Operations

```bash
# Run a single check (JK)
docker compose run --rm jk_feed /app/shared/run.sh

# Fetch all episodes
docker compose run --rm jk_feed /app/shared/run.sh --fetch-all

# Test Telegram notifications
docker compose run --rm jk_feed /app/shared/run.sh --test

# Quiet run (no notifications)
docker compose run --rm jk_feed /app/shared/run.sh --quiet
```

## 🛠️ Container Management

```bash
# Follow logs
docker compose logs -f jk_feed
docker compose logs -f v_feed

# Restart services
docker compose restart jk_feed
docker compose restart v_feed
docker compose restart web
```

## 📖 Usage

_(see [Manual Operations](#manual-operations) above)_

## ➕ Adding New Podcasts

1. Add your feed slug and XML filename to `FEEDS` in `.env`, e.g.  
   `FEEDS=jutarnja-kronika:jk.xml,vijesti:v.xml,myshow:ms.xml`
2. Extend `PATH_MAP` in `scripts_v/feed.py` and/or `scripts_jk/feed.py` if needed.
3. Rebuild & redeploy:
   ```bash
   docker compose build
   docker compose up -d
   ```

## 📜 Scripts Explained

- **shared/run.sh** – orchestrates fetching, logging, and notifications  
- **shared/start-cron.sh** – cron entrypoint for periodic checks  
- **shared/render-conf.sh** – generates `nginx.conf` based on `FEEDS`  
- **scripts_jk/feed.py**, **scripts_v/feed.py** – main scraping and feed-gen logic  
- **shared/notify_failure.sh** – alerts on errors  
- **shared/test.sh**, **shared/debug-cron.sh** – helper/test scripts  

## 🔧 Telegram Notifications

All notification settings are controlled via environment variables (see [Configuration](#configuration)).  

## 🆘 Troubleshooting

- Check logs (`docker compose logs`) for stack traces  
- Ensure your `.env` values are correct and that the HRT site layout hasn’t changed  
- Manually invoke `/app/shared/run.sh --fetch-all --test`  

## 📡 API Endpoints

- `GET /<feed-slug>` – Returns the RSS XML  
- `GET /<feed-slug>/artwork.jpg` – Cover art  
- `GET /` – Health check  

## 🏗️ Development

- Build locally: `docker compose build --no-cache`  
- Run interactively: `docker compose run --rm jk_feed bash`  

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- **HRT (Croatian Radio Television)** for providing the source content  
- **Docker Community** for excellent containerization tools  
- **Telegram** for notification API  
- **feedgen** Python library for RSS generation  
