import glob
import sys
import xml.etree.ElementTree as ET

def validate_feed(path):
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        print(f"❌ FAILED to parse XML {path}: {e}")
        return False

    root = tree.getroot()
    if not root.tag.lower().endswith('rss'):
        print(f"❌ Root tag is not <rss> in {path} (got {root.tag})")
        return False

    channel = root.find('channel')
    if channel is None:
        print(f"❌ No <channel> element found in {path}")
        return False

    title = channel.findtext('title')
    if not title or not title.strip():
        print(f"❌ Empty <title> in channel of {path}")
        return False

    items = channel.findall('item')
    if len(items) == 0:
        print(f"❌ No <item> entries found in {path}")
        return False

    print(f"✅ {path} OK ({len(items)} items)")
    return True

def main():
    xml_files = glob.glob('feeds/*.xml')
    if not xml_files:
        print("❌ No feeds/*.xml files found")
        sys.exit(1)

    all_ok = True
    for xml in xml_files:
        if not validate_feed(xml):
            all_ok = False

    if not all_ok:
        sys.exit(1)

if __name__ == '__main__':
    main()
