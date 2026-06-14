import argparse
import json
import os
import socket
import sys
import time
import urllib.parse
import urllib.request
import zipfile
from io import BytesIO


USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

_ORIGINAL_GETADDRINFO = socket.getaddrinfo


def force_gutenberg_ip(ip):
    def getaddrinfo(host, port, family=0, type=0, proto=0, flags=0):
        if host == "www.gutenberg.org":
            return _ORIGINAL_GETADDRINFO(ip, port, family, type, proto, flags)
        return _ORIGINAL_GETADDRINFO(host, port, family, type, proto, flags)

    socket.getaddrinfo = getaddrinfo


def timed_get(url, timeout):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/epub+zip,application/octet-stream,text/plain,*/*",
            "Accept-Language": "it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7",
            "Connection": "close",
        },
    )
    start = time.perf_counter()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(request, timeout=timeout) as response:
        data = response.read()
        status = response.status
        content_type = response.headers.get("content-type", "")
    elapsed = time.perf_counter() - start
    return status, content_type, data, elapsed


def plain_text_url(book):
    formats = book.get("formats") or {}
    for key, value in formats.items():
        if key.lower().startswith("text/plain") and not _is_zip_url(value):
            return value
    for key, value in formats.items():
        if key.lower().startswith("text/plain"):
            return value
    return None


def epub_url(book):
    book_id = book.get("id")
    if book_id:
        return f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}-images.epub"
    formats = book.get("formats") or {}
    for key, value in formats.items():
        lower_key = key.lower()
        lower_url = value.lower()
        if ("epub" in lower_key or ".epub" in lower_url) and ".noimages" not in lower_url:
            return value
    for key, value in formats.items():
        lower_key = key.lower()
        lower_url = value.lower()
        if "epub" in lower_key or ".epub" in lower_url:
            return value
    if book_id:
        return f"https://www.gutenberg.org/ebooks/{book_id}.epub3.images"
    return None


def _is_zip_url(value):
    path = urllib.parse.urlparse(value).path.lower()
    return path.endswith(".zip")


def decode_text(data, url):
    if _is_zip_url(url) or data[:4] == b"PK\x03\x04":
        with zipfile.ZipFile(BytesIO(data)) as archive:
            names = sorted(
                archive.namelist(),
                key=lambda name: (0 if name.lower().endswith(".txt") else 1, name.lower()),
            )
            for name in names:
                if name.endswith("/"):
                    continue
                text = archive.read(name).decode("utf-8", errors="replace").strip()
                if text:
                    return text, name
        raise RuntimeError("ZIP senza testo leggibile")
    return data.decode("utf-8", errors="replace"), None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("query", nargs="?", default="pinocchio")
    parser.add_argument("--lang", default="it")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--gutenberg-ip")
    args = parser.parse_args()
    if args.gutenberg_ip:
        force_gutenberg_ip(args.gutenberg_ip)
        print(f"FORCE_GUTENBERG_IP={args.gutenberg_ip}")
    print(f"HTTP_PROXY={os.environ.get('HTTP_PROXY') or os.environ.get('http_proxy') or ''}")
    print(f"HTTPS_PROXY={os.environ.get('HTTPS_PROXY') or os.environ.get('https_proxy') or ''}")

    search_url = "https://sonarpad.com/api/gutenberg/search.php?" + urllib.parse.urlencode(
        {"q": args.query, "lang": args.lang, "page_size": "5"}
    )

    print(f"SEARCH {search_url}")
    status, content_type, data, elapsed = timed_get(search_url, args.timeout)
    print(f"SEARCH status={status} seconds={elapsed:.2f} bytes={len(data)} type={content_type}")
    payload = json.loads(data.decode("utf-8", errors="replace"))
    results = payload.get("results") or []
    print(f"RESULTS count={len(results)} total={payload.get('count')}")
    if not results:
        return 2

    book = results[0]
    print(f"BOOK id={book.get('id')} title={book.get('title')!r}")
    epub = epub_url(book)
    if epub:
        print(f"EPUB_URL {epub}")
        try:
            status, content_type, data, elapsed = timed_get(epub, args.timeout)
            print(f"EPUB_DOWNLOAD status={status} seconds={elapsed:.2f} bytes={len(data)} type={content_type}")
            if 200 <= status < 300:
                print("IMPORT_MODE epub")
                return 0
        except Exception as error:
            print(f"EPUB_DOWNLOAD_ERROR {type(error).__name__}: {error}")

    url = plain_text_url(book)
    print(f"TEXT_URL {url}")
    if not url:
        print("NO_TEXT_URL")
        return 3

    try:
        status, content_type, data, elapsed = timed_get(url, args.timeout)
    except Exception as error:
        print(f"DOWNLOAD_ERROR {type(error).__name__}: {error}")
        return 4
    print(f"DOWNLOAD status={status} seconds={elapsed:.2f} bytes={len(data)} type={content_type}")
    text, zip_entry = decode_text(data, url)
    if zip_entry:
        print(f"ZIP_ENTRY {zip_entry}")
    print(f"TEXT length={len(text)} preview={text[:120]!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
