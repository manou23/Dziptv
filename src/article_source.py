"""Read only publicly published VibeCritic review pages."""
from __future__ import annotations
import re, time
from urllib.parse import urljoin, urlparse
import requests
from bs4 import BeautifulSoup

SITE = "https://vibecritic.pages.dev"
HEADERS = {"User-Agent": "VibeCriticVideoBot/1.0"}

def get(url):
    r = requests.get(url, headers=HEADERS, timeout=35)
    r.raise_for_status()
    return r.text

def locs(xml):
    soup = BeautifulSoup(xml, "xml")
    return [x.get_text(strip=True) for x in soup.find_all("loc")]

def discover_sitemaps():
    found = []
    try:
        robots = get(SITE + "/robots.txt")
        found.extend(re.findall(r"(?im)^sitemap:\s*(\S+)", robots))
    except requests.RequestException:
        pass
    for path in ("/sitemap.xml", "/sitemap_index.xml", "/sitemap-index.xml"):
        candidate = SITE + path
        if candidate not in found:
            found.append(candidate)
    valid = []
    for url in dict.fromkeys(found):
        try:
            xml = get(url)
            if "<urlset" in xml or "<sitemapindex" in xml:
                valid.append((url, xml))
        except requests.RequestException:
            continue
    return valid

def meta(soup, *names):
    for name in names:
        node = soup.find("meta", attrs={"property": name}) or soup.find("meta", attrs={"name": name})
        if node and node.get("content"):
            return node["content"].strip()
    return ""

def is_review_article_url(url):
    parsed = urlparse(url)
    if parsed.netloc.lower() != "vibecritic.pages.dev":
        return False
    match = re.fullmatch(r"/reviews/([^/]+)/?", parsed.path)
    if not match:
        return False
    slug = match.group(1).lower()
    return slug not in {"index", "page", "category", "tag", "archive", "all"}

def extract(url):
    if not is_review_article_url(url):
        return None
    soup = BeautifulSoup(get(url), "html.parser")
    canonical = soup.find("link", rel="canonical")
    url = urljoin(url, canonical.get("href", url)) if canonical else url
    if not is_review_article_url(url):
        return None
    title = meta(soup, "og:title") or (soup.title.get_text(" ", strip=True) if soup.title else "")
    description = meta(soup, "og:description", "description")
    poster = meta(soup, "og:image")
    article = soup.find("article") or soup.find("main")
    if not article:
        return None
    for node in article.select("script,style,nav,footer,header,button,form"):
        node.decompose()
    body = re.sub(r"\s+", " ", article.get_text(" ", strip=True)).strip()
    if len(body) < 900 or not title:
        return None
    heading = article.find(["h1", "h2"])
    title_ar = heading.get_text(" ", strip=True) if heading else title.split("|")[0].strip()
    images = [urljoin(url, poster)] if poster else []
    for image in article.find_all("img"):
        source = image.get("src") or image.get("data-src")
        if source:
            candidate = urljoin(url, source)
            if candidate not in images:
                images.append(candidate)
    kind = "game" if re.search(r"game|لعبة", url + " " + title, re.I) else ("tv" if re.search(r"series|مسلسل", url + " " + title, re.I) else "movie")
    return {
        "uid": url.rstrip("/").split("/")[-1], "kind": kind,
        "title_en": title, "title_ar": title_ar, "release": "",
        "genres": [], "overview": description or body[:1200], "facts": [],
        "images": images[:8], "source": "VibeCritic",
        "article_url": url, "article_text": body[:16000],
    }

def list_published_articles():
    article_urls = []
    for _, xml in discover_sitemaps():
        for url in locs(xml):
            if url.endswith(".xml"):
                try:
                    article_urls.extend(locs(get(url)))
                except requests.RequestException:
                    continue
            elif is_review_article_url(url):
                article_urls.append(url)
    results = []
    for url in dict.fromkeys(article_urls):
        try:
            article = extract(url)
            if article:
                results.append(article)
        except (requests.RequestException, ValueError) as exc:
            print(f"[article-source] skipped {url}: {type(exc).__name__}", flush=True)
        time.sleep(0.15)
    return results  # Preserve sitemap order; publishers commonly list newest reviews first.
