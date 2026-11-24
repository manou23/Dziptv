#!/usr/bin/env python3
"""Render a source-grounded long-form Arabic review of GTA VI."""
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

SCREENSHOTS = [
    "https://cdn.mos.cms.futurecdn.net/qDWmfWxjCRtjdCx87CawfT.jpg",
    "https://cdn.mos.cms.futurecdn.net/nSSNKBj8gq6db3b2dQtDfT.jpg",
    "https://cdn.mos.cms.futurecdn.net/6srYisgzG2TFQLyqN3hjfT.jpg",
    "https://cdn.mos.cms.futurecdn.net/ZLqX8iGNdcX4qLziG8rbaT.jpg",
    "https://cdn.mos.cms.futurecdn.net/mbBEYSD4qY2NTyjbFLd2fT.jpg",
    "https://cdn.mos.cms.futurecdn.net/TdAvEyR4vSBYAXLwjC5KJT.jpg",
]

SCENES = [
    {"narration": "بعد ثلاثة عشر عاماً من الانتظار، وصلت جراند ثفت أوتو ستة أخيراً. لكن السؤال الحقيقي ليس كم باعت اللعبة، ولا كم كانت التوقعات ضخمة. السؤال هو: هل قدمت روكستار تجربة تستحق هذا الانتظار الطويل؟ في هذه المراجعة سنفصل عناصر اللعبة بهدوء، ونوضح أين تتألق، وأين تظهر الملاحظات، ومن اللاعب الذي سيستمتع بها أكثر.", "image_prompt": "Grand Theft Auto VI Vice City skyline at sunset, cinematic game screenshot"},
    {"narration": "تدور المغامرة في ولاية ليونيدا الخيالية، وتعود فايس سيتي لتكون القلب النابض لعالم واسع يتجاوز شوارع المدينة. التنوع بين المناطق الحضرية والطبيعة والطرق المفتوحة يمنح الاستكشاف إيقاعاً متغيراً. الفكرة ليست مجرد خريطة كبيرة؛ الأهم هو الإحساس بأن لكل مكان طابعه، وأن التنقل نفسه قد يقود إلى موقف لم تكن تبحث عنه أصلاً.", "image_prompt": "GTA VI Leonida coastal highway and Vice City environment"},
    {"narration": "في قلب الحكاية نجد جيسون ولوسيا، وهما ليسا مجرد شخصيتين تتناوبان تنفيذ المهام. العلاقة بينهما هي المحور الذي يمنح الأحداث جانباً إنسانياً، وسط عالم الجريمة والمال والمخاطر. هذا الاختيار يغير نبرة القصة؛ فبدلاً من أن تكون المطاردات والانفجارات هي كل شيء، يصبح لدينا أيضاً سؤال عن الثقة والطموح والقرارات التي يتخذها شخصان معاً.", "image_prompt": "GTA VI Jason and Lucia cinematic in-game scene"},
    {"narration": "كتابة الشخصيات والحوار من أبرز نقاط القوة التي تتكرر في انطباعات المراجعين. السخرية الاجتماعية حاضرة، لكن اللعبة لا تعتمد على النكات وحدها. هناك لحظات هادئة تسمح للشخصيات بالتنفس، ثم تعود الأحداث لتصنع توتراً أو فوضى. هذا التوازن يساعد العالم على أن يبدو مكاناً يعيش فيه الناس، لا مجرد مسرح ينتظر وصول اللاعب.", "image_prompt": "GTA VI characters in a lively Vice City neighborhood"},
    {"narration": "العالم المفتوح هو النجم الأكبر. التفاصيل الصغيرة، وتغيرات الطقس، وحركة السكان، والمواقف العفوية تجعل التجول مكافأة بحد ذاته. قد تنطلق في طريقك إلى مهمة محددة، ثم تتوقف بسبب حدث جانبي أو مشهد غير متوقع. وفق مراجعة كريتيف بلو، قوة اللعبة لا تكمن في حجم الخريطة فقط، بل في كثافة التفاصيل وما تصنعه من قصص غير مخطط لها.", "image_prompt": "GTA VI dense open world street life dynamic weather"},
    {"narration": "الأنشطة الجانبية تضيف أسباباً كثيرة للبقاء خارج القصة الرئيسية. بين السباقات والصيد والأنشطة الترفيهية والألعاب المصغرة، توجد مساحات لتغيير الإيقاع. ليست كل الأنشطة متساوية في العمق، لكن تنوعها يجعل ليونيدا أكثر من مجرد سلسلة مهام متتابعة. اللاعب الذي يحب التجول واكتشاف التفاصيل سيجد هنا قيمة كبيرة، حتى عندما لا يتقدم في القصة.", "image_prompt": "GTA VI side activities fishing racing leisure in-game"},
    {"narration": "في القيادة والمطاردات، تحافظ اللعبة على هوية السلسلة، لكنها تقدم ذلك ضمن عالم أكثر كثافة وتفاعلاً. السيارات والطرق والشرطة تصنع لحظات فوضوية يمكن أن تبدأ من خطأ بسيط. وتسمح المهام أحياناً بمقاربات مختلفة، من التخطيط إلى المواجهة المباشرة. المهم أن اللعبة تمنحك مساحة لتجربة أسلوبك، لا أن تحصر كل موقف في حل واحد.", "image_prompt": "GTA VI high speed car chase through Vice City"},
    {"narration": "القتال والتسلل جزء أساسي من التجربة، وتبرز قيمة الاختيار في طريقة التعامل مع المواجهات. يمكن أن تكون المواجهة صاخبة وسريعة، أو أكثر حذراً بحسب الموقف والأدوات المتاحة. بعض المهام السينمائية تبدو مصممة بإحكام شديد، وهذا يمنحها إيقاعاً قوياً، لكنه قد يقلل أحياناً من الحرية التي اعتدنا ربطها بالعالم المفتوح. هنا يظهر أحد أهم التنازلات.", "image_prompt": "GTA VI cinematic action mission combat cover scene"},
    {"narration": "على المستوى البصري، الانطباع العام قوي جداً. الإضاءة والانعكاسات والوجوه والبيئات تساعد على جعل المدينة مقنعة، كما أن تصميم الصوت والموسيقى يضيفان الكثير إلى أجواء القيادة والاستكشاف. هذه العناصر لا تعمل منفصلة؛ إنها تتكامل لتجعل الانتقال من شارع مزدحم إلى منطقة هادئة تجربة محسوسة. لكن جودة الصورة وحدها لا تكفي للحكم على كل جوانب الأداء.", "image_prompt": "GTA VI visual fidelity neon night rain cityscape"},
    {"narration": "أما الأداء التقني، فهناك نقطة تستحق الانتباه قبل الشراء. مراجعة كريتيف بلو التي اختبرت نسخة بلايستيشن خمسة أشارت إلى معدل ثلاثين إطاراً في الثانية، مع ملاحظة ظهور بعض العناصر متأخرة أحياناً. هذا لا يلغي جودة التجربة، لكنه قد يهم اللاعبين الذين يفضلون ستين إطاراً أو أكثر. لذلك من الأفضل معرفة هذه المعلومة ومراجعة الاختبارات الخاصة بالمنصة التي تملكونها.", "image_prompt": "GTA VI console gameplay performance city scene PS5"},
    {"narration": "هل توجد عيوب؟ نعم، وأهمها أن بعض المهمات قد تشعر بأنها أكثر تقييداً من الحرية التي يقدمها العالم، كما أن إيقاع القصة قد يتباطأ في بعض المقاطع بحسب ذوق اللاعب. كذلك فإن معدل الإطارات المحدود لن يناسب الجميع. هذه ملاحظات حقيقية، لكنها لا تمحو نقاط القوة؛ بل تساعد على تكوين صورة متوازنة بدلاً من التعامل مع اللعبة كأنها مثالية بلا نقاش.", "image_prompt": "GTA VI dramatic mission staging cinematic city scene"},
    {"narration": "الخلاصة: جراند ثفت أوتو ستة تقدم عالماً مفتوحاً غنياً، وشخصيتين محوريتين، ومزيجاً قوياً من القصة والفوضى واللحظات العفوية. مراجعة كريتيف بلو منحتها خمسة من خمسة، مع إشادة واضحة بالعالم والشخصيات والتفاصيل، لكنها سجلت ملاحظات على بعض المهمات ومعدل الإطارات. إذا كنتم تحبون ألعاب العالم المفتوح الطويلة، فهي تجربة تستحق الاهتمام. أخبرونا: ما أكثر شيء تريدون تجربته أولاً؟", "image_prompt": "GTA VI Vice City sunset skyline final cinematic review shot"},
]

WORK = {
    "uid": "game:gta-vi-review-long-2026",
    "kind": "game",
    "title_ar": "جراند ثفت أوتو 6",
    "title_en": "Grand Theft Auto VI",
    "release": "2026-11-19",
    "genres": ["Action-adventure", "Open world"],
    "facts": [
        "Platforms: PlayStation 5, Xbox Series X|S",
        "Release date: 19 November 2026",
        "Creative Bloq review verdict: 5/5",
        "Creative Bloq PS5 review notes 30fps and occasional pop-in",
    ],
    "article_url": "https://www.creativebloq.com/reviews/gta-6-review-holy-sh-t-its-good",
    "source": "VibeCritic",
}

PLAN = {
    "format": "long",
    "title": "مراجعة GTA 6 الكاملة: القصة والعالم المفتوح والأداء",
    "description": (
        "مراجعة عربية مطولة للعبة Grand Theft Auto VI بعد إطلاقها في 19 نوفمبر 2026. "
        "نناقش القصة وجيسون ولوسيا والعالم المفتوح والأنشطة والقتال والقيادة والجوانب التقنية، "
        "مع عرض نقاط القوة والملاحظات دون حرق أحداث القصة. "
        "اعتمدنا على مراجعات منشورة، ومنها Creative Bloq وTechRadar، وعلى معلومات Rockstar الرسمية. "
        "المصادر: https://www.creativebloq.com/reviews/gta-6-review-holy-sh-t-its-good "
        "| https://www.techradar.com/gaming/gta-6-review "
        "| https://www.rockstargames.com/newswire/article/39akk424a9oo53/grand-theft-auto-vi-now-available"
    ),
    "hashtags": ["GTA6", "GTAVI", "جراند_ثفت_أوتو", "مراجعة_كاملة", "Gaming"],
    "scenes": SCENES,
}

_image_index = 0

def credited_screenshot(_prompt: str, destination: Path) -> bool:
    global _image_index
    url = SCREENSHOTS[_image_index % len(SCREENSHOTS)]
    _image_index += 1
    try:
        response = requests.get(url, timeout=60, headers={"User-Agent": "Mozilla/5.0 (compatible; VibeCriticVideo/1.0)"})
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
    if len(SCENES) != 12 or not 520 <= words <= 760:
        raise SystemExit(f"Long-form script quality gate failed: {len(SCENES)} scenes, {words} words.")
    QUEUE.mkdir(exist_ok=True)
    OUT.mkdir(exist_ok=True)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {"version": 1, "items": []}
    items = manifest.setdefault("items", [])
    if any(item.get("id") == WORK["uid"] for item in items):
        raise SystemExit("GTA VI long video already exists in the queue; refusing to overwrite it.")
    pipeline.W, pipeline.H = 1920, 1080
    pipeline.VOICE = "ar-SA-HamedNeural"
    pipeline.ai_image = credited_screenshot
    video = pipeline.render(WORK, PLAN, "gta6-review-long.mp4")
    seconds = pipeline.media_duration(video)
    if not 210 <= seconds <= 480:
        video.unlink(missing_ok=True)
        raise SystemExit(f"Long video duration gate failed: {seconds:.1f}s is outside 210–480 seconds.")
    if _image_index < 8:
        video.unlink(missing_ok=True)
        raise SystemExit(f"Visual quality gate failed: only {_image_index}/12 credited screenshots downloaded.")
    destination = QUEUE / "gta6-review-long.mp4"
    shutil.copy2(video, destination)
    if destination.stat().st_size < 500_000:
        destination.unlink(missing_ok=True)
        raise SystemExit("MP4 size validation failed.")
    items.append({
        "id": WORK["uid"],
        "file": "queue/gta6-review-long.mp4",
        "title_ar": WORK["title_ar"],
        "title_en": WORK["title_en"],
        "release": WORK["release"],
        "genres": WORK["genres"],
        "facts": WORK["facts"],
        "kind": "game",
        "format": "long",
        "youtube_title": PLAN["title"],
        "description": PLAN["description"],
        "hashtags": PLAN["hashtags"],
        "article_url": WORK["article_url"],
        "source": "VibeCritic",
        "duration_seconds": round(seconds, 2),
        "visual_credit": "Creative Bloq review screenshots, credited to Rockstar Games",
    })
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"QUEUE_READY: {destination} | duration={seconds:.2f}s | bytes={destination.stat().st_size} | screenshots={_image_index}/12 | words={words}")

if __name__ == "__main__":
    main()
