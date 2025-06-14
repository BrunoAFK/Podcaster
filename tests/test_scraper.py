import sys
import requests

FEEDS = [
    'https://yourdomain.com/jutarnja-kronika',
    'https://yourdomain.com/vijesti',
]

def test_feed(url):
    r = requests.get(url, timeout=10)
    if r.status_code != 200:
        print(f"❌ {url} returned HTTP {r.status_code}")
        sys.exit(1)
    if '<rss' not in r.text:
        print(f"❌ {url} did not contain an <rss> tag")
        sys.exit(1)
    print(f"✅ {url} OK")

def main():
    for feed in FEEDS:
        test_feed(feed)

if __name__ == '__main__':
    main()
