"""Read only publicly published VibeCritic review pages."""
from __future__ import annotations
import re, time
from urllib.parse import urljoin
import requests
from bs4 import BeautifulSoup
SITE = "https://vibecritic.pages.dev"
HEADERS = {"User-Agent": "VibeCriticVideoBot/1.0"}
def get(url):
    r=requests.get(url,headers=HEADERS,timeout=35); r.raise_for_status(); return r.text
def locs(xml):
    s=BeautifulSoup(xml,"xml")
    return [x.get_text(strip=True) for x in s.find_all("loc")]
def meta(s,*names):
    for n in names:
        x=s.find("meta",attrs={"property":n}) or s.find("meta",attrs={"name":n})
        if x and x.get("content"): return x["content"].strip()
    return ""
def extract(url):
    s=BeautifulSoup(get(url),"html.parser")
    canonical=s.find("link",rel="canonical")
    url=canonical.get("href",url) if canonical else url
    if "/reviews/" not in url: return None
    title=meta(s,"og:title") or (s.title.get_text(" ",strip=True) if s.title else "")
    desc=meta(s,"og:description","description")
    poster=meta(s,"og:image")
    art=s.find("article") or s.find("main")
    if not art: return None
    for n in art.select("script,style,nav,footer,header,button,form"): n.decompose()
    body=re.sub(r"\s+"," ",art.get_text(" ",strip=True)).strip()
    if len(body)<900 or not title: return None
    h=art.find(["h1","h2"])
    ar=h.get_text(" ",strip=True) if h else title.split("|")[0].strip()
    imgs=[urljoin(url,poster)] if poster else []
    for im in art.find_all("img"):
        src=im.get("src") or im.get("data-src")
        if src:
            v=urljoin(url,src)
            if v not in imgs: imgs.append(v)
    kind="game" if re.search(r"game|لعبة",url+" "+title,re.I) else ("tv" if re.search(r"series|مسلسل",url+" "+title,re.I) else "movie")
    return {"uid":url.rstrip("/").split("/")[-1],"kind":kind,"title_en":title,"title_ar":ar,"release":"","genres":[],"overview":desc or body[:1200],"facts":[],"images":imgs[:8],"source":"VibeCritic","article_url":url,"article_text":body[:16000]}
def list_published_articles():
    root=locs(get(SITE+"/sitemap.xml"))
    urls=[]
    for u in root:
        if u.endswith(".xml"):
            try: urls.extend(locs(get(u)))
            except requests.RequestException: continue
        elif "/reviews/" in u: urls.append(u)
    out=[]
    for u in dict.fromkeys(urls):
        try:
            x=extract(u)
            if x: out.append(x)
        except (requests.RequestException,ValueError) as e:
            print(f"[article-source] skipped {u}: {type(e).__name__}",flush=True)
        time.sleep(.15)
    return sorted(out,key=lambda x:x["uid"])
