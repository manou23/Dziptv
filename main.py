#!/usr/bin/env python3
"""Automated VibeCritic article-to-YouTube video pipeline. See README.md.

Pipeline:
  Published VibeCritic review -> Gemini short/long scripts (source-grounded)
  -> Edge TTS voice -> Pollinations / TMDb images -> Pillow caption frames
  -> FFmpeg -> YouTube upload -> state file (so a work is never repeated)
"""
from __future__ import annotations

import asyncio
import datetime as dt
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import quote

import arabic_reshaper
import requests
from bs4 import BeautifulSoup
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from src.article_source import extract, list_published_articles

try:
    from bidi import get_display
except ImportError:  # older python-bidi releases
    from bidi.algorithm import get_display

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output"
STATE_FILE = ROOT / "state" / "videos.json"
PREVIEW_STATE_FILE = ROOT / "state" / "previews.json"
W, H = 1080, 1920

TMDB_KEY = os.getenv("TMDB_API_KEY", "")
RAWG_KEY = os.getenv("RAWG_API_KEY", "")
GEMINI_KEY = os.getenv("GEMINI_API_KEY", "")
# Keep the model order configurable: primary first, then independent fallbacks.
# These are stable Flash models listed in Google's current Gemini API model catalog.
GEMINI_MODELS = [
    m.strip()
    for m in os.getenv(
        "GEMINI_MODELS",
        "gemini-3.8-flash,gemini-3.6-flash,gemini-3.5-flash-lite",
    ).split(",")
    if m.strip()
]
VOICE = os.getenv("TTS_VOICE", "ar-SA-HamedNeural")
TTS_RATE = os.getenv("TTS_RATE", "+0%")
KINDS = [k.strip() for k in os.getenv("KINDS", "movie,tv,game").split(",") if k.strip()]
PRIVACY = os.getenv("YT_PRIVACY", "public")
DRY_RUN = os.getenv("DRY_RUN", "0") == "1"
KIND_LABEL = {"movie": "فيلم", "tv": "مسلسل", "game": "لعبة"}


def log(msg: str) -> None:
    print(msg, flush=True)


# --------------------------------------------------------------------------- #
# HTTP helper (never logs query strings, so API keys stay out of the logs)
# --------------------------------------------------------------------------- #
def http_get(url: str, params: dict | None = None, tries: int = 3, timeout: int = 60):
    last: Exception | None = None
    for i in range(tries):
        try:
            r = requests.get(url, params=params, timeout=timeout)
            if r.status_code == 200:
                return r
            last = RuntimeError(f"HTTP {r.status_code} from {url.split('?')[0]}")
        except requests.RequestException as e:
            last = RuntimeError(f"{type(e).__name__} from {url.split('?')[0]}")
        time.sleep(2 * (i + 1))
    raise last  # type: ignore[misc]


# --------------------------------------------------------------------------- #
# State (which works were already published)
# --------------------------------------------------------------------------- #
def load_state() -> dict:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    return {"articles": {}, "log": []}


def save_state(state: dict) -> None:
    state["articles"] = dict(list(state.get("articles", {}).items())[-500:])
    state["log"] = state.get("log", [])[-100:]
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def load_preview_state() -> dict:
    if PREVIEW_STATE_FILE.exists():
        return json.loads(PREVIEW_STATE_FILE.read_text(encoding="utf-8"))
    return {"articles": {}}


def save_preview_state(state: dict) -> None:
    state["articles"] = dict(list(state.get("articles", {}).items())[-500:])
    PREVIEW_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW_STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


# --------------------------------------------------------------------------- #
# 1. Pick a trending work (TMDb for movies/series, RAWG for games)
# --------------------------------------------------------------------------- #
def tmdb_work(kind: str, tmdb_id: int) -> dict:
    base = f"https://api.themoviedb.org/3/{kind}/{tmdb_id}"
    en = http_get(base, {"api_key": TMDB_KEY, "language": "en-US"}).json()
    ar = http_get(base, {"api_key": TMDB_KEY, "language": "ar"}).json()
    title_en = en.get("title") or en.get("name") or ""
    facts = []
    if (en.get("vote_count") or 0) >= 50:
        facts.append(f"TMDb user rating: {en['vote_average']:.1f}/10 from {en['vote_count']} votes")
    if kind == "movie" and en.get("runtime"):
        facts.append(f"Runtime: {en['runtime']} minutes")
    if kind == "tv":
        facts.append(f"Seasons: {en.get('number_of_seasons')}, episodes: {en.get('number_of_episodes')}")
    if en.get("tagline"):
        facts.append(f"Tagline: {en['tagline']}")
    images = []
    if en.get("backdrop_path"):
        images.append("https://image.tmdb.org/t/p/w1280" + en["backdrop_path"])
    if en.get("poster_path"):
        images.append("https://image.tmdb.org/t/p/w780" + en["poster_path"])
    return {
        "uid": f"{kind}:{tmdb_id}",
        "kind": kind,
        "title_en": title_en,
        "title_ar": ar.get("title") or ar.get("name") or title_en,
        "release": en.get("release_date") or en.get("first_air_date") or "",
        "genres": [g["name"] for g in en.get("genres", [])],
        "overview": (en.get("overview") or "").strip(),
        "facts": facts,
        "images": images,
        "source": "TMDb",
    }


def rawg_work(game_id: int) -> dict | None:
    d = http_get(f"https://api.rawg.io/api/games/{game_id}", {"key": RAWG_KEY}).json()
    if (d.get("esrb_rating") or {}).get("slug") == "adults-only":
        return None
    facts = []
    if d.get("metacritic"):
        facts.append(f"Metacritic score: {d['metacritic']}")
    if d.get("rating") and (d.get("ratings_count") or 0) >= 20:
        facts.append(f"RAWG user rating: {d['rating']}/5 from {d['ratings_count']} ratings")
    if d.get("platforms"):
        facts.append("Platforms: " + ", ".join(p["platform"]["name"] for p in d["platforms"][:6]))
    if d.get("developers"):
        facts.append("Developer: " + ", ".join(x["name"] for x in d["developers"][:2]))
    images = [u for u in (d.get("background_image"), d.get("background_image_additional")) if u]
    return {
        "uid": f"game:{game_id}",
        "kind": "game",
        "title_en": d.get("name", ""),
        "title_ar": d.get("name", ""),
        "release": d.get("released") or "",
        "genres": [g["name"] for g in d.get("genres", [])],
        "overview": re.sub(r"\s+", " ", d.get("description_raw") or "").strip()[:900],
        "facts": facts,
        "images": images,
        "source": "RAWG",
    }


def candidate_ids(kind: str) -> list[int]:
    if kind in ("movie", "tv"):
        r = http_get(f"https://api.themoviedb.org/3/trending/{kind}/week", {"api_key": TMDB_KEY})
        return [x["id"] for x in r.json().get("results", [])]
    today = dt.date.today()
    window = f"{today - dt.timedelta(days=120)},{today + dt.timedelta(days=60)}"
    r = http_get(
        "https://api.rawg.io/api/games",
        {"key": RAWG_KEY, "dates": window, "ordering": "-added", "page_size": 20},
    )
    return [x["id"] for x in r.json().get("results", [])]


def pick_work(state: dict, preview_state: dict | None = None) -> dict:
    articles = list_published_articles()
    if DRY_RUN and preview_state is not None:
        previewed = preview_state.setdefault("articles", {})
        remaining = [a for a in articles if a["uid"] not in previewed]
        if not remaining:
            # Start a fresh preview cycle only after every eligible article was sampled.
            preview_state["articles"] = {}
            remaining = articles
        articles = remaining

    for article in articles:
        record = state.get("articles", {}).get(article["uid"], {})
        videos = record.get("videos", {})
        if not videos.get("short") or not videos.get("long"):
            return article
    raise SystemExit("No eligible new VibeCritic article is available.")


# --------------------------------------------------------------------------- #
# 2. Script with Gemini (grounded in the retrieved data only)
# --------------------------------------------------------------------------- #
PROMPT = """أنت كاتب سيناريو لقناة يوتيوب عربية متخصصة في الأفلام والمسلسلات والألعاب.
اكتب سيناريو فيديو قصير (Short) مدته 45 إلى 55 ثانية بالعربية الفصحى المبسطة عن العمل الموصوف في البيانات أدناه.

قواعد صارمة:
- استخدم فقط المعلومات الواردة في البيانات، ولا تخترع تفاصيل أو أسماء أو أرقامًا أو أحداثًا.
- لا تكشف مفاجآت الحبكة.
- الجملة الأولى خطّاف يثير الفضول ولا تزيد عن 12 كلمة.
- 6 مشاهد بهذا الترتيب: خطّاف، فكرة العمل، ما يميّزه، التقييم والأرقام إن وُجدت، لمن يناسب، دعوة للاشتراك مع سؤال للتعليقات.
- اكتب 6 مشاهد، في كل مشهد 15 إلى 17 كلمة منطوقة (المجموع 90 إلى 102 كلمة) لتناسب مدة صوتية فعلية تقارب 45 إلى 60 ثانية. اشرح الفكرة بوضوح مع الالتزام بالمعلومات المتاحة فقط، واجعل كل مشهد جملة أو جملتين طبيعيتين سهلتي النطق.
- اكتب اسم العمل بالحروف العربية في السرد.
- image_prompt: وصف بالإنجليزية لصورة سينمائية عمودية تناسب المشهد، بلا نصوص ولا شعارات ولا وجوه أشخاص حقيقيين ولا شخصيات محمية بحقوق؛ فضّل الأجواء والمناظر والأشياء الرمزية.
- title: عنوان عربي جذاب لا يتجاوز 70 حرفًا، صادق لا يعد بما لا يقدمه الفيديو.
- description: سطران عن الفيديو.
- hashtags: من 4 إلى 6 وسوم عربية أو إنجليزية بدون علامة #.

أعد JSON فقط وبدون أي نص آخر بهذا الشكل:
{"title": "...", "description": "...", "hashtags": ["..."], "scenes": [{"narration": "...", "image_prompt": "..."}]}

البيانات:
@@WORK@@
"""


def gemini_json(prompt: str) -> dict:
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.8, "responseMimeType": "application/json"},
    }
    last = "no attempt"
    transient_statuses = {408, 429, 500, 502, 503, 504}

    for model in GEMINI_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        # Retry temporary service overloads, then move to the next model.
        for attempt in range(3):
            try:
                r = requests.post(
                    url, json=body, timeout=120,
                    headers={"x-goog-api-key": GEMINI_KEY, "Content-Type": "application/json"},
                )
            except requests.RequestException as exc:
                last = f"{model}: network error ({type(exc).__name__})"
                log(f"Gemini temporary network error on {model} ({attempt + 1}/3).")
                if attempt < 2:
                    delay = min(90, 20 * (2 ** attempt)) + random.uniform(0, 5)
                    log(f"Gemini retrying {model} in {delay:.0f}s.")
                    time.sleep(delay)
                    continue
                break

            if r.status_code == 200:
                try:
                    response_text = r.json()["candidates"][0]["content"]["parts"][0]["text"]
                    parsed = json.loads(
                        re.sub(r"^```(?:json)?|```$", "", response_text.strip()).strip()
                    )
                    if not isinstance(parsed, dict):
                        raise TypeError(
                            "Gemini response must be a JSON object, not " + type(parsed).__name__
                        )
                    log(f"Gemini script generated successfully with {model}.")
                    return parsed
                except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
                    last = f"{model}: invalid JSON response ({type(exc).__name__})"
                    log(f"Gemini returned an invalid response from {model}; trying the next model.")
                    break

            try:
                error = r.json().get("error", {})
                detail = str(error.get("message") or error.get("status") or "").replace("\n", " ")[:240]
            except (ValueError, AttributeError):
                detail = ""
            last = f"{model}: HTTP {r.status_code}" + (f" - {detail}" if detail else "")

            if r.status_code in transient_statuses and attempt < 2:
                retry_after = r.headers.get("Retry-After", "")
                try:
                    server_delay = float(retry_after)
                except (TypeError, ValueError):
                    server_delay = 0
                delay = max(server_delay, min(90, 20 * (2 ** attempt)))
                delay = min(120, delay) + random.uniform(0, 5)
                log(
                    f"Gemini {r.status_code} on {model} "
                    f"({attempt + 1}/3); retrying in {delay:.0f}s."
                )
                time.sleep(delay)
                continue

            if r.status_code in transient_statuses:
                log(f"Gemini {r.status_code} persists on {model}; switching to the next fallback.")
            else:
                log(f"Gemini request failed on {model} with HTTP {r.status_code}; switching model.")
            break

    log(f"All Gemini models failed ({last}); checking the optional DeepSeek fallback.")
    deepseek_error = "not configured"
    if DEEPSEEK_KEY:
        try:
            return deepseek_json(prompt)
        except Exception as exc:
            deepseek_error = f"{type(exc).__name__}: {exc}"
            log(f"DeepSeek fallback failed ({deepseek_error}); trying OpenAI if configured.")
    else:
        log("DeepSeek fallback skipped: DEEPSEEK_API_KEY is not configured.")

    try:
        return openai_json(prompt)
    except Exception as exc:
        raise RuntimeError(
            f"All configured providers failed. Gemini: {last}. "
            f"DeepSeek: {deepseek_error}. OpenAI: {type(exc).__name__}: {exc}"
        ) from exc



# --------------------------------------------------------------------------- #
# 2b. Optional DeepSeek fallback (after all Gemini models, before OpenAI)
# --------------------------------------------------------------------------- #
DEEPSEEK_KEY = os.getenv("DEEPSEEK_API_KEY", "").strip()
DEEPSEEK_MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-chat").strip()


def deepseek_json(prompt: str) -> dict:
    """Generate a JSON script through DeepSeek's OpenAI-compatible API."""
    if not DEEPSEEK_KEY:
        raise RuntimeError("DEEPSEEK_API_KEY is not configured.")

    url = "https://api.deepseek.com/chat/completions"
    body = {
        "model": DEEPSEEK_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "response_format": {"type": "json_object"},
        "temperature": 0.8,
        "max_tokens": 8192,
    }
    last = "unknown error"
    for attempt in range(2):
        try:
            r = requests.post(
                url,
                json=body,
                timeout=180,
                headers={
                    "Authorization": f"Bearer {DEEPSEEK_KEY}",
                    "Content-Type": "application/json",
                },
            )
        except requests.RequestException as exc:
            last = f"network error ({type(exc).__name__})"
            if attempt == 0:
                log("DeepSeek fallback: temporary network error; retrying once.")
                time.sleep(5)
                continue
            break

        if r.status_code == 200:
            try:
                response_text = r.json()["choices"][0]["message"]["content"]
                cleaned = re.sub(
                    r"^\s*```(?:json)?\s*|\s*```\s*$",
                    "",
                    str(response_text).strip(),
                    flags=re.IGNORECASE,
                ).strip()
                parsed = json.loads(cleaned)
                if not isinstance(parsed, dict):
                    raise TypeError("DeepSeek response must be a JSON object")
                log(f"DeepSeek fallback generated script successfully with {DEEPSEEK_MODEL}.")
                return parsed
            except (KeyError, IndexError, TypeError, ValueError, json.JSONDecodeError) as exc:
                last = f"invalid JSON response ({type(exc).__name__})"
                break

        try:
            error = r.json().get("error", {})
            detail = str(error.get("message") or error.get("code") or "").replace("\n", " ")[:240]
        except (ValueError, AttributeError):
            detail = ""
        last = f"HTTP {r.status_code}" + (f" - {detail}" if detail else "")
        if r.status_code in {408, 429, 500, 502, 503, 504} and attempt == 0:
            log(f"DeepSeek fallback returned HTTP {r.status_code}; retrying once.")
            time.sleep(5)
            continue
        break

    raise RuntimeError(f"DeepSeek fallback failed ({DEEPSEEK_MODEL}): {last}")


# --------------------------------------------------------------------------- #
# 2c. OpenAI fallback (called only after Gemini and optional DeepSeek fail)
# --------------------------------------------------------------------------- #
OPENAI_KEY = os.getenv("OPENAI_API_KEY", "").strip()
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-6-luna").strip()


def openai_json(prompt: str) -> dict:
    if not OPENAI_KEY:
        raise RuntimeError(
            "Gemini failed and OPENAI_API_KEY is not configured; "
            "add it as a GitHub Actions secret to enable the optional fallback."
        )

    url = "https://api.openai.com/v1/responses"
    body = {
        "model": OPENAI_MODEL,
        "input": prompt,
        "text": {"format": {"type": "json_object"}},
        "max_output_tokens": 9000,
    }
    last = "unknown error"
    for attempt in range(2):
        try:
            r = requests.post(
                url,
                json=body,
                timeout=180,
                headers={
                    "Authorization": f"Bearer {OPENAI_KEY}",
                    "Content-Type": "application/json",
                },
            )
        except requests.RequestException as exc:
            last = f"network error ({type(exc).__name__})"
            if attempt == 0:
                log("OpenAI fallback: temporary network error; retrying once.")
                time.sleep(5)
                continue
            break

        if r.status_code == 200:
            try:
                payload = r.json()
                response_text = payload.get("output_text", "")
                if not response_text:
                    chunks = []
                    for item in payload.get("output", []):
                        for part in item.get("content", []):
                            if part.get("type") == "output_text":
                                chunks.append(part.get("text", ""))
                    response_text = "\n".join(chunks)
                cleaned = re.sub(
                    r"^\s*```(?:json)?\s*|\s*```\s*$",
                    "",
                    response_text.strip(),
                    flags=re.IGNORECASE,
                ).strip()
                parsed = json.loads(cleaned)
                if not isinstance(parsed, dict):
                    raise TypeError("OpenAI response must be a JSON object")
                log(f"OpenAI fallback generated script successfully with {OPENAI_MODEL}.")
                return parsed
            except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
                last = f"invalid JSON response ({type(exc).__name__})"
                break

        try:
            error = r.json().get("error", {})
            detail = str(error.get("message") or error.get("code") or "").replace("\n", " ")[:240]
        except (ValueError, AttributeError):
            detail = ""
        last = f"HTTP {r.status_code}" + (f" - {detail}" if detail else "")
        if r.status_code in {408, 429, 500, 502, 503, 504} and attempt == 0:
            log(f"OpenAI fallback returned HTTP {r.status_code}; retrying once.")
            time.sleep(5)
            continue
        break

    raise RuntimeError(f"OpenAI fallback failed ({OPENAI_MODEL}): {last}")


def write_script(work: dict) -> dict:
    data = {
        "type": KIND_LABEL[work["kind"]],
        "title_english": work["title_en"],
        "title_arabic": work["title_ar"],
        "release_date": work["release"],
        "genres": work["genres"],
        "overview": work["overview"],
        "facts": work["facts"],
        "article_excerpt": work.get("article_text", "")[:9000],
    }
    prompt = PROMPT.replace("@@WORK@@", json.dumps(data, ensure_ascii=False, indent=2))
    previous_plan = None
    for attempt in range(4):
        active_prompt = prompt
        if previous_plan is not None:
            previous_json = json.dumps(previous_plan, ensure_ascii=False)
            active_prompt = (
                prompt
                + "\n\nمهمتك الآن إصلاح النص السابق، لا تبدأ من الصفر. "
                + "احتفظ بالمعلومات الصحيحة، واضبط السرد ليصبح بين 90 و102 كلمة. "
                + "اجعل كل واحد من المشاهد الستة يحتوي 15 إلى 17 كلمة منطوقة. "
                + "لا تضف حقائق غير موجودة، وأعد JSON كاملاً فقط. "
                + f"عدد الكلمات الحالي {previous_words}، وهذا النص يحتاج إلى توسعة واضحة:\n{previous_json}"
            )
        plan = gemini_json(active_prompt)
        scenes = plan.get("scenes") or []
        if not isinstance(scenes, list) or any(not isinstance(scene, dict) for scene in scenes):
            log("Script rejected: Gemini scenes must be a list of scene objects; requesting repair.")
            previous_plan = None
            continue
        words = sum(len(str(s.get("narration", "")).split()) for s in scenes)
        if len(scenes) == 6 and all(str(s.get("narration", "")).strip() for s in scenes) and 90 <= words <= 102:
            plan["title"] = str(plan.get("title") or work["title_ar"])[:95]
            return plan
        previous_plan = plan
        previous_words = words
        log(f"Script rejected (scenes={len(scenes)}, words={words}), requesting expansion ({attempt + 1}/4)")
    raise RuntimeError("Gemini could not produce a 90–102 word, six-scene script after repair attempts.")


LONG_PROMPT = """اكتب سيناريو فيديو تحليلي عربي لقناة VibeCritic مدته 5 إلى 8 دقائق.
استخدم معلومات المقال فقط ولا تخترع حقائق أو مشاهد أو تجارب. لا حشو ولا تكرار. أنشئ 8 إلى 12 مشهداً متماسكاً بمجموع 650 إلى 900 كلمة منطوقة: مقدمة، سياق، نقاط القوة، نقاط الضعف، تحليل، لمن يناسب، حكم نهائي وخاتمة.
أعد JSON فقط: {"title":"عنوان","description":"وصف","hashtags":["..."],"scenes":[{"narration":"...","image_prompt":"cinematic atmosphere, no text, no logos"}]}
المقال المنشور:
@@ARTICLE@@
"""

def write_long_script(work: dict) -> dict | None:
    source = work.get("article_text", "")
    if len(source) < 1800:
        log("Long video skipped: insufficient article material.")
        return None
    prompt = LONG_PROMPT.replace("@@ARTICLE@@", source[:14000])
    for attempt in range(3):
        plan = gemini_json(prompt)
        scenes = plan.get("scenes") or []
        if not isinstance(scenes, list) or any(not isinstance(scene, dict) for scene in scenes):
            log("Long script rejected: Gemini scenes must be a list of scene objects.")
            continue
        words = sum(len(str(s.get("narration", "")).split()) for s in scenes)
        if 8 <= len(scenes) <= 12 and 650 <= words <= 900 and all(str(s.get("narration", "")).strip() for s in scenes):
            plan["title"] = str(plan.get("title") or work["title_ar"])[:95]
            log(f"Long script accepted: {words} words.")
            return plan
        log(f"Long script rejected: scenes={len(scenes)}, words={words}.")
    log("Long video skipped: quality gate rejected the source-based script.")
    return None


# --------------------------------------------------------------------------- #
# 3. Voice (Edge TTS, free)
# --------------------------------------------------------------------------- #
async def synth_all(texts: list[str], folder: Path) -> list[Path]:
    import edge_tts

    paths = []
    for i, text in enumerate(texts):
        p = folder / f"voice_{i}.mp3"
        for attempt in range(4):
            try:
                await edge_tts.Communicate(text, VOICE, rate=TTS_RATE).save(str(p))
                if p.exists() and p.stat().st_size > 1000:
                    break
            except Exception as e:  # network / service hiccups
                log(f"TTS retry scene {i}: {type(e).__name__}")
            await asyncio.sleep(3 * (attempt + 1))
        else:
            raise RuntimeError(f"TTS failed for scene {i}. Try updating edge-tts.")
        paths.append(p)
    return paths


def media_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(path)],
        capture_output=True, text=True, check=True,
    ).stdout
    return float(out.strip())


def validate_short_duration(path: Path) -> float:
    seconds = media_duration(path)
    if not 45 <= seconds <= 60:
        path.unlink(missing_ok=True)
        raise RuntimeError(f"Short video rejected: duration {seconds:.1f}s is outside the 45–60s target.")
    log(f"Short duration accepted: {seconds:.1f}s.")
    return seconds


# --------------------------------------------------------------------------- #
# 4. Images + caption frames (Pillow does the Arabic shaping, not FFmpeg)
# --------------------------------------------------------------------------- #
def download_image(url: str, path: Path, tries: int = 3) -> bool:
    for i in range(tries):
        try:
            r = requests.get(url, timeout=120)
            if r.status_code == 200 and len(r.content) > 5000:
                path.write_bytes(r.content)
                Image.open(path).verify()
                return True
        except Exception:
            pass
        time.sleep(3 * (i + 1))
    return False


def ai_image(prompt: str, path: Path) -> bool:
    orientation = "portrait" if H > W else "landscape"
    full = f"{prompt}, cinematic, dramatic lighting, {orientation} composition, no text"
    url = (
        f"https://image.pollinations.ai/prompt/{quote(full)}"
        f"?width={W}&height={H}&nologo=true&seed={random.randint(1, 999999)}"
    )
    return download_image(url, path, tries=2)


def create_fallback_scene_image(path: Path, scene_index: int) -> None:
    """Create original abstract artwork locally when the image provider is unavailable."""
    rng = random.Random(f"{scene_index}:{W}:{H}")
    palettes = [
        ((8, 18, 38), (20, 78, 105), (8, 12, 28)),
        ((28, 12, 42), (102, 42, 91), (13, 10, 29)),
        ((9, 35, 30), (24, 105, 83), (7, 17, 24)),
        ((38, 24, 10), (142, 82, 29), (18, 13, 10)),
        ((15, 20, 48), (64, 75, 143), (8, 10, 25)),
        ((36, 13, 17), (128, 48, 52), (15, 9, 18)),
    ]
    top, middle, bottom = palettes[scene_index % len(palettes)]
    img = Image.new("RGB", (W, H))
    gradient_draw = ImageDraw.Draw(img)
    for y in range(H):
        t = y / max(1, H - 1)
        if t < 0.58:
            q = t / 0.58
            a, b = top, middle
        else:
            q = (t - 0.58) / 0.42
            a, b = middle, bottom
        color = tuple(int(a[k] * (1 - q) + b[k] * q) for k in range(3))
        gradient_draw.line((0, y, W, y), fill=color)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx = rng.randint(int(W * 0.25), int(W * 0.75))
    cy = rng.randint(int(H * 0.25), int(H * 0.62))
    radius = int(min(W, H) * rng.uniform(0.24, 0.38))
    accent = tuple(min(255, v + 75) for v in middle)
    gd.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=(*accent, 105))
    glow = glow.filter(ImageFilter.GaussianBlur(max(18, int(min(W, H) * 0.07))))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    draw = ImageDraw.Draw(img, "RGBA")

    # Original geometric layers: deliberately abstract, with no borrowed artwork.
    for n in range(9):
        margin = int(min(W, H) * (0.04 + n * 0.025))
        offset = rng.randint(-int(W * 0.2), int(W * 0.2))
        draw.arc(
            (margin + offset, margin, W - margin + offset, H - margin),
            start=rng.randint(0, 90), end=rng.randint(180, 360),
            fill=(220, 235, 255, rng.randint(18, 48)),
            width=max(2, int(min(W, H) * 0.003)),
        )
    for _ in range(18):
        x = rng.randint(0, W)
        y = rng.randint(0, H)
        size = rng.randint(max(8, int(min(W, H) * 0.006)), max(12, int(min(W, H) * 0.025)))
        draw.ellipse((x-size, y-size, x+size, y+size), outline=(235, 242, 255, 55), width=2)
    img.convert("RGB").save(path, quality=92, optimize=True)


def find_font() -> str:
    env = os.getenv("FONT_PATH")
    if env and Path(env).exists():
        return env
    try:
        out = subprocess.run(
            ["fc-match", "-f", "%{file}", "sans-serif:lang=ar:bold"],
            capture_output=True, text=True, timeout=10,
        ).stdout.strip()
        if out and Path(out).exists():
            return out
    except Exception:
        pass
    for c in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf",
    ):
        if Path(c).exists():
            return c
    raise RuntimeError("No Arabic-capable font found. Install fonts-noto-core or set FONT_PATH.")


def shape(text: str) -> str:
    return get_display(arabic_reshaper.reshape(text))


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    # BASIC layout: we already shaped and reordered the text ourselves.
    return ImageFont.truetype(path, size, layout_engine=ImageFont.Layout.BASIC)


def wrap(text: str, font: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    lines: list[str] = []
    cur: list[str] = []
    for word in text.split():
        trial = " ".join(cur + [word])
        if not cur or font.getlength(shape(trial)) <= max_w:
            cur.append(word)
        else:
            lines.append(" ".join(cur))
            cur = [word]
    if cur:
        lines.append(" ".join(cur))
    return lines


def draw_block(img: Image.Image, text: str, font, center_y: int, max_w: int | None = None) -> None:
    if max_w is None:
        max_w = int(W * 0.86)
    d = ImageDraw.Draw(img)
    lines = wrap(text, font, max_w)
    lh = int(font.size * 1.5)
    y = center_y - (len(lines) * lh) // 2
    for line in lines:
        s = shape(line)
        x = (W - font.getlength(s)) / 2
        d.text((x, y), s, font=font, fill="white", stroke_width=6, stroke_fill="black")
        y += lh


def background(path: Path) -> Image.Image:
    img = Image.open(path).convert("RGB")
    scale = max(W / img.width, H / img.height)
    img = img.resize((int(img.width * scale) + 1, int(img.height * scale) + 1), Image.LANCZOS)
    left, top = (img.width - W) // 2, (img.height - H) // 2
    img = img.crop((left, top, left + W, top + H)).convert("RGBA")
    grad = Image.linear_gradient("L").resize((W, H))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    shade.putalpha(grad.point(lambda p: int(50 + p * 0.55)))
    return Image.alpha_composite(img, shade).convert("RGB")


def chunk_words(text: str, max_words: int = 6) -> list[str]:
    chunks: list[str] = []
    cur: list[str] = []
    for w in text.split():
        cur.append(w)
        if len(cur) >= max_words or (len(cur) >= 3 and re.search(r"[.،؛؟!?:]$", w)):
            chunks.append(" ".join(cur))
            cur = []
    if cur:
        if chunks and len(cur) == 1:
            chunks[-1] += " " + cur[0]
        else:
            chunks.append(" ".join(cur))
    return [re.sub(r"[.،؛]+$", "", c) for c in chunks]


def run_ffmpeg(args: list[str]) -> None:
    p = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args], capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError("ffmpeg failed: " + p.stderr[-800:])


def render(work: dict, plan: dict, output_name: str = "short.mp4") -> Path:
    tmp = OUT / "work"
    shutil.rmtree(tmp, ignore_errors=True)
    (tmp / "frames").mkdir(parents=True)
    scenes = plan["scenes"]

    voices = asyncio.run(synth_all([s["narration"] for s in scenes], tmp))
    durations = [media_duration(p) for p in voices]
    log(f"Voice done: {sum(durations):.1f}s total")

    # Use generated illustrative scenes only; do not republish copyrighted article artwork.
    bgs = []
    for i, scene in enumerate(scenes):
        p = tmp / f"bg_{i}.jpg"
        prompt = str(scene.get("image_prompt") or f"Cinematic symbolic atmosphere for {work['title_en']}")
        if not ai_image(prompt, p):
            log(f"WARNING: generated image for scene {i + 1} unavailable; using original local abstract artwork.")
            create_fallback_scene_image(p, i)
        bgs.append(p)
        time.sleep(0.5)

    font_path = find_font()
    cap_font, title_font = load_font(font_path, 80), load_font(font_path, 58)
    entries: list[tuple[Path, float]] = []
    for i, (s, dur, bg_path) in enumerate(zip(scenes, durations, bgs)):
        base = background(bg_path)
        draw_block(base, work["title_ar"], title_font, center_y=230)
        chunks = chunk_words(str(s["narration"]))
        total = sum(len(c) for c in chunks) or 1
        for j, chunk in enumerate(chunks):
            frame = base.copy()
            draw_block(frame, chunk, cap_font, center_y=int(H * 0.64))
            fp = tmp / "frames" / f"s{i}_{j:02d}.png"
            frame.save(fp)
            entries.append((fp, max(0.6, dur * len(chunk) / total)))

    lst = tmp / "frames.txt"
    lst.write_text(
        "".join(f"file '{p}'\nduration {d:.3f}\n" for p, d in entries) + f"file '{entries[-1][0]}'\n",
        encoding="utf-8",
    )
    alst = tmp / "audio.txt"
    alst.write_text("".join(f"file '{p}'\n" for p in voices), encoding="utf-8")
    run_ffmpeg(["-f", "concat", "-safe", "0", "-i", str(alst), "-c:a", "aac", "-b:a", "160k", str(tmp / "voice.m4a")])

    video = OUT / output_name
    run_ffmpeg([
        "-f", "concat", "-safe", "0", "-i", str(lst), "-i", str(tmp / "voice.m4a"),
        "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
        "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", str(video),
    ])
    log(f"Video ready: {video} ({media_duration(video):.1f}s)")
    return video


# --------------------------------------------------------------------------- #
# 5. Upload to YouTube (Data API v3, free quota)
# --------------------------------------------------------------------------- #
def youtube_seo(work: dict, plan: dict) -> tuple[str, str, list[str]]:
    """Build accurate bilingual YouTube metadata from verified work/article fields."""
    kind_ar = KIND_LABEL.get(work.get("kind"), "عمل")
    kind_en = {"movie": "movie", "tv": "TV series", "game": "video game"}.get(work.get("kind"), "")
    title_ar = re.sub(r"\\s+", " ", str(work.get("title_ar") or "")).strip()
    title_en = re.sub(r"\\s+", " ", str(work.get("title_en") or "")).strip()
    release = str(work.get("release") or "")[:4]
    base_title = re.sub(r"\\s+", " ", str(plan.get("title") or title_ar or title_en)).strip()
    # Ensure the actual work name appears in the title without keyword stuffing.
    if title_ar and title_ar.casefold() not in base_title.casefold() and title_en.casefold() not in base_title.casefold():
        base_title = f"{title_ar}: {base_title}"
    optimized_title = base_title[:100].rstrip(" |:-")

    # Tags are built only from the work's real names, year, type, genres,
    # platform facts and the script's relevant topic hashtags.
    candidates: list[str] = []
    def add_tag(value: object) -> None:
        tag = re.sub(r"\\s+", " ", str(value or "")).strip().lstrip("#")
        if not tag or len(tag) > 100:
            return
        if tag.casefold() not in {x.casefold() for x in candidates}:
            candidates.append(tag)

    add_tag(title_en)
    add_tag(title_ar)
    if title_en and release:
        add_tag(f"{title_en} {release}")
    if title_ar and release:
        add_tag(f"{title_ar} {release}")
    add_tag(kind_ar)
    add_tag(kind_en)
    if work.get("kind") == "game":
        add_tag("ألعاب")
        add_tag("gaming")
    elif work.get("kind") == "movie":
        add_tag("أفلام")
        add_tag("movies")
    elif work.get("kind") == "tv":
        add_tag("مسلسلات")
        add_tag("TV series")
    for genre in (work.get("genres") or [])[:8]:
        add_tag(genre)
    for fact in (work.get("facts") or []):
        match = re.search(r"^Platforms:\\s*(.+)$", str(fact), re.I)
        if match:
            for platform in match.group(1).split(",")[:6]:
                add_tag(platform.strip())
    for tag in (plan.get("hashtags") or [])[:6]:
        add_tag(tag)

    # YouTube allows up to 500 characters across all tags; stay comfortably below it.
    final_tags: list[str] = []
    used = 0
    for tag in candidates:
        extra = len(tag) + (1 if final_tags else 0)
        if used + extra > 480 or len(final_tags) >= 25:
            continue
        final_tags.append(tag)
        used += extra

    genre_text = "، ".join(str(g) for g in (work.get("genres") or [])[:3])
    context = f"{kind_ar}"
    if release:
        context += f" من {release}"
    if genre_text:
        context += f" من نوع {genre_text}"
    search_intro = f"{title_ar or title_en} ({title_en or title_ar}) — فيديو عن {context}."
    base_description = str(plan.get("description") or "").strip()
    hashtags = []
    for tag in (plan.get("hashtags") or [])[:5]:
        clean = re.sub(r"[^\\w\\u0600-\\u06FF-]", "", str(tag).strip().lstrip("#").replace(" ", ""))
        if clean and clean.casefold() not in {x.casefold() for x in hashtags}:
            hashtags.append(clean)
    hashtags = hashtags[:4]
    hashtags.append("Shorts" if plan.get("format") == "short" else "VibeCritic")
    credit = (
        "This product uses the TMDB API but is not endorsed or certified by TMDB. https://www.themoviedb.org"
        if work.get("source") == "TMDb"
        else ("Game data: RAWG https://rawg.io" if work.get("source") == "RAWG" else "Source: VibeCritic published review https://vibecritic.pages.dev")
    )
    description = (
        f"{search_intro}\\n{base_description}\\n\\n"
        + " ".join(f"#{tag}" for tag in hashtags)
        + f"\\n\\nالمراجعة الكاملة: {work.get('article_url', '')}\\nتم إنتاج هذا الفيديو بمساعدة الذكاء الاصطناعي.\\n{credit}"
    )[:4800]
    return optimized_title, description, final_tags


def build_description(work: dict, plan: dict) -> tuple[str, list[str]]:
    _, description, tags = youtube_seo(work, plan)
    return description, tags


def upload(video: Path, work: dict, plan: dict) -> str:
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload

    creds = Credentials(
        None,
        refresh_token=os.environ["YT_REFRESH_TOKEN"],
        token_uri="https://oauth2.googleapis.com/token",
        client_id=os.environ["YT_CLIENT_ID"],
        client_secret=os.environ["YT_CLIENT_SECRET"],
        scopes=["https://www.googleapis.com/auth/youtube.upload"],
    )
    yt = build("youtube", "v3", credentials=creds, cache_discovery=False)
    optimized_title, description, tags = youtube_seo(work, plan)
    log(f"YouTube SEO: title ready; {len(tags)} relevant tags ({sum(len(t) for t in tags) + max(0, len(tags) - 1)}/500 tag characters).")
    body = {
        "snippet": {
            "title": optimized_title,
            "description": description,
            "tags": tags,
            "categoryId": "20" if work["kind"] == "game" else "24",  # Gaming or Entertainment
            "defaultLanguage": "ar",
            "defaultAudioLanguage": "ar",
        },
        "status": {
            "privacyStatus": PRIVACY,
            "selfDeclaredMadeForKids": False,
            "containsSyntheticMedia": True,  # AI-content disclosure
        },
    }
    for attempt in range(2):
        try:
            req = yt.videos().insert(
                part="snippet,status", body=body,
                media_body=MediaFileUpload(str(video), mimetype="video/mp4", chunksize=8 * 1024 * 1024, resumable=True),
            )
            resp = None
            while resp is None:
                _, resp = req.next_chunk()
            return resp["id"]
        except HttpError as e:
            if attempt == 0 and e.resp.status == 400 and "ynthetic" in str(e):
                body["status"].pop("containsSyntheticMedia", None)  # older API surface: retry without it
                continue
            raise
    raise RuntimeError("upload failed")


# --------------------------------------------------------------------------- #
def main() -> None:
    global W, H
    if not GEMINI_KEY:
        raise SystemExit("GEMINI_API_KEY is missing.")
    if not DRY_RUN and not all(os.getenv(k) for k in ("YT_CLIENT_ID", "YT_CLIENT_SECRET", "YT_REFRESH_TOKEN")):
        raise SystemExit("YouTube secrets are missing.")
    OUT.mkdir(exist_ok=True)
    state = load_state()
    preview_state = load_preview_state() if DRY_RUN else None
    manual_url = os.getenv("MANUAL_ARTICLE_URL", "").strip()
    video_format = os.getenv("VIDEO_FORMAT", "both").strip().lower()
    if video_format not in {"short", "long", "both"}:
        raise SystemExit("VIDEO_FORMAT must be short, long, or both.")
    if manual_url:
        work = extract(manual_url)
        if not work:
            raise SystemExit("The supplied URL is not a valid, publicly published VibeCritic review article.")
        log(f"Manual selection: {work['title_ar']} | {work['article_url']} | format={video_format}")
    else:
        work = pick_work(state, preview_state)
        log(f"Automatic selection: {work['title_ar']} | {work['article_url']} | format={video_format}")
    record = state.setdefault("articles", {}).setdefault(work["uid"], {
        "article_url": work["article_url"], "title": work["title_ar"], "videos": {}
    })
    videos = record.setdefault("videos", {})

    if DRY_RUN:
        W, H = 1080, 1920
        short_plan = write_script(work)
        short_plan["format"] = "short"
        short_video = render(work, short_plan, "short.mp4")
        validate_short_duration(short_video)
        long_plan = write_long_script(work)
        long_video = None
        if long_plan:
            long_plan["format"] = "long"
            W, H = 1920, 1080
            long_video = render(work, long_plan, "long.mp4")
            seconds = media_duration(long_video)
            if not 270 <= seconds <= 480:
                log(f"Long video rejected by duration gate: {seconds:.1f}s.")
                long_video.unlink(missing_ok=True)
                long_video = None
        (OUT / "metadata.json").write_text(json.dumps({
            "work": work["uid"], "article_url": work["article_url"],
            "short": short_plan, "long": long_plan
        }, ensure_ascii=False, indent=2), encoding="utf-8")
        preview_state.setdefault("articles", {})[work["uid"]] = {
            "article_url": work["article_url"],
            "title": work["title_ar"],
            "previewed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "short_generated": short_video.exists(),
            "long_generated": bool(long_video and long_video.exists()),
        }
        save_preview_state(preview_state)
        log("DRY_RUN=1: upload skipped; preview state saved separately from publishing state.")
        return

    if video_format in {"short", "both"} and not videos.get("short"):
        W, H = 1080, 1920
        short_plan = write_script(work)
        short_plan["format"] = "short"
        short_video = render(work, short_plan, "short.mp4")
        validate_short_duration(short_video)
        short_id = upload(short_video, work, short_plan)
        videos["short"] = short_id
        save_state(state)
        log(f"Short uploaded: https://youtu.be/{short_id} ({PRIVACY})")

    if video_format in {"long", "both"} and not videos.get("long"):
        long_plan = write_long_script(work)
        if long_plan:
            long_plan["format"] = "long"
            W, H = 1920, 1080
            long_video = render(work, long_plan, "long.mp4")
            seconds = media_duration(long_video)
            if 270 <= seconds <= 480:
                long_id = upload(long_video, work, long_plan)
                videos["long"] = long_id
                log(f"Long video uploaded: https://youtu.be/{long_id} ({PRIVACY})")
            else:
                log(f"Long video rejected by duration gate: {seconds:.1f}s.")
                videos["long"] = "skipped-duration-quality-gate"
                long_video.unlink(missing_ok=True)
        else:
            videos["long"] = "skipped-insufficient-article-material"
        save_state(state)

    record["article_url"] = work["article_url"]
    record["title"] = work["title_ar"]
    state.setdefault("log", []).append({
        "uid": work["uid"], "article_url": work["article_url"],
        "title": work["title_ar"], "videos": videos,
        "date": dt.date.today().isoformat()
    })
    save_state(state)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # fail loudly so the Action turns red and notifies you
        log(f"ERROR: {type(exc).__name__}: {exc}")
        sys.exit(1)