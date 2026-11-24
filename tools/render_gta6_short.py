#!/usr/bin/env python3
"""Render the first VibeCritic Video review short: GTA VI.

Uses the existing Arabic Edge-TTS + FFmpeg renderer, with credited game screenshots
from Creative Bloq's review (images credited there to Rockstar Games).
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import requests
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import main as pipeline  # noqa: E402

QUEUE = ROOT / "queue"
MANIFEST = QUEUE / "manifest.json"
OUT = ROOT / "output"

# Screenshots embedded in Creative Bloq's GTA VI review; the article credits
# the screenshots to Rockstar Games. Used here for review/commentary context.
SCREENSHOTS = [
    "https://cdn.mos.cms.futurecdn.net/qDWmfWxjCRtjdCx87CawfT.jpg",
    "https://cdn.mos.cms.futurecdn.net/nSSNKBj8gq6db3b2dQtDfT.jpg",
    "https://cdn.mos.cms.futurecdn.net/6srYisgzG2TFQLyqN3hjfT.jpg",
    "https://cdn.mos.cms.futurecdn.net/ZLqX8iGNdcX4qLziG8rbaT.jpg",
    "https://cdn.mos.cms.futurecdn.net/mbBEYSD4qY2NTyjbFLd2fT.jpg",
    "https://cdn.mos.cms.futurecdn.net/TdAvEyR4vSBYAXLwjC5KJT.jpg",
]

SCENES = [
    {
        "narration": "بعد ثلاثة عشر عاماً من الانتظار، هل تستحق جراند ثفت أوتو ستة كل هذه الضجة؟",
        "image_prompt": "GTA VI review opening, Vice City street at golden hour",
    },
    {
        "narration": "تأخذنا اللعبة إلى ولاية ليونيدا، حيث تعود فايس سيتي في عالم مفتوح مليء بالتفاصيل والحياة.",
        "image_prompt": "GTA VI Leonida open world and Vice City",
    },
    {
        "narration": "تتقدم القصة مع جيسون ولوسيا، وثنائيهما يمنح المغامرة قلباً إنسانياً وسط الجريمة والمطاردات والقرارات المصيرية.",
        "image_prompt": "GTA VI Jason and Lucia story relationship",
    },
    {
        "narration": "أبرز ما يلفت الانتباه عالم نابض، أحداث عفوية، وشخصيات تتفاعل مع اللاعب بطرق غير متوقعة.",
        "image_prompt": "GTA VI emergent open world activities",
    },
    {
        "narration": "لكن المشاهد السينمائية تقيد بعض المهام، ومعدل ثلاثين إطاراً قد لا يرضي الباحثين عن سلاسة أعلى.",
        "image_prompt": "GTA VI cinematic mission and console performance",
    },
    {
        "narration": "وفق مراجعات النقاد، التجربة استثنائية حتى الآن؛ شاركونا: هل تستحق جي تي إيه ستة لقب لعبة الجيل؟",
        "image_prompt": "GTA VI review verdict Vice City night skyline",
    },
]

WORK = {
    "uid": "game:gta-vi-review-short-2026",
    "kind": "game",
    "title_ar": "جراند ثفت أوتو 6",
    "title_en": "Grand Theft Auto VI",
    "release": "2026-11-19",
    "genres": ["Action-adventure", "Open world"],
    "facts": [
        "Platforms: PlayStation 5, Xbox Series X|S",
        "Release date: 19 November 2026",
        "Creative Bloq review verdict: 5/5",
        "Performance note: 30fps on PS5 review build",
    ],
    "article_url": "https://www.creativebloq.com/reviews/gta-6-review-holy-sh-t-its-good",
    "source": "VibeCritic",
}

PLAN = {
    "format": "short",
    "title": "مراجعة GTA 6: هل تستحق كل هذا الانتظار؟",
    "description": (
        "مراجعة سريعة للعبة Grand Theft Auto VI بعد إطلاقها في 19 نوفمبر 2026. "
        "نستعرض العالم المفتوح وجيسون ولوسيا وأبرز نقاط القوة والملاحظات، "
        "استناداً إلى مراجعة Creative Bloq ومعلومات Rockstar الرسمية. "
        "الصور من لقطات اللعبة المنشورة في مراجعة Creative Bloq والمنسوبة إلى Rockstar Games. "
        "المصادر: https://www.creativebloq.com/reviews/gta-6-review-holy-sh-t-its-good "
        "| https://www.rockstargames.com/newswire/article/39akk424a9oo53/grand-theft-auto-vi-now-available"
    ),
    "hashtags": ["GTA6", "GTAVI", "جراند_ثفت_أوتو", "مراجعة_ألعاب", "Gaming"],
    "scenes": SCENES,
}

_image_index = 0

def credited_screenshot(_prompt: str, destination: Path) -> bool:
    global _image_index
    url = SCREENSHOTS[_image_index % len(SCREENSHOTS)]
    _image_index += 1
    try:
        response = requests.get(
            url,
            timeout=60,
            headers={"User-Agent": "Mozilla/5.0 (compatible; VibeCriticVideo/1.0)"},
        )
        response.raise_for_status()
        if len(response.content) < 10_000:
            return False
        destination.write_bytes(response.content)
        with Image.open(destination) as image:
            image.verify()
        return True
    except Exception as exc:
        print(f"Screenshot download failed ({type(exc).__name__}); refusing placeholder art.")
        destination.unlink(missing_ok=True)
        return False


def main() -> None:
    words = sum(len(scene["narration"].split()) for scene in SCENES)
    if len(SCENES) != 6 or not 90 <= words <= 102:
        raise SystemExit(f"Script quality gate failed: {len(SCENES)} scenes, {words} words.")

    QUEUE.mkdir(exist_ok=True)
    OUT.mkdir(exist_ok=True)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {"version": 1, "items": []}
    items = manifest.setdefault("items", [])
    if any(item.get("id") == WORK["uid"] for item in items):
        raise SystemExit("GTA VI short already exists in the queue; refusing to overwrite it.")

    pipeline.W, pipeline.H = 1080, 1920
    pipeline.VOICE = "ar-SA-HamedNeural"
    pipeline.ai_image = credited_screenshot
    video = pipeline.render(WORK, PLAN, "gta6-review-short.mp4")
    seconds = pipeline.validate_short_duration(video)
    if _image_index < 4:
        video.unlink(missing_ok=True)
        raise SystemExit(f"Visual quality gate failed: only {_image_index}/6 screenshots downloaded.")

    destination = QUEUE / "gta6-review-short.mp4"
    shutil.copy2(video, destination)
    if destination.stat().st_size < 100_000:
        destination.unlink(missing_ok=True)
        raise SystemExit("MP4 size validation failed.")

    items.append({
        "id": WORK["uid"],
        "file": "queue/gta6-review-short.mp4",
        "title_ar": WORK["title_ar"],
        "title_en": WORK["title_en"],
        "release": WORK["release"],
        "genres": WORK["genres"],
        "facts": WORK["facts"],
        "kind": "game",
        "format": "short",
        "youtube_title": PLAN["title"],
        "description": PLAN["description"],
        "hashtags": PLAN["hashtags"],
        "article_url": WORK["article_url"],
        "source": "VibeCritic",
        "duration_seconds": round(seconds, 2),
        "visual_credit": "Creative Bloq review screenshots, credited to Rockstar Games",
    })
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"QUEUE_READY: {destination} | duration={seconds:.2f}s | bytes={destination.stat().st_size} | screenshots={_image_index}/6")


if __name__ == "__main__":
    main()
