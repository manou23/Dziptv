#!/usr/bin/env python3
"""Validate and publish selected pre-rendered queue videos, one at a time."""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import main as pipeline

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "queue" / "manifest.json"
STATE = ROOT / "state" / "queue.json"


def probe_video(path: Path, expected_format: str, expected_duration: float) -> None:
    result = subprocess.run(
        [
            "ffprobe", "-v", "error", "-show_entries",
            "format=duration:stream=codec_type,width,height",
            "-of", "json", str(path),
        ],
        check=True, capture_output=True, text=True, timeout=60,
    )
    data = json.loads(result.stdout)
    streams = data.get("streams", [])
    video = next((s for s in streams if s.get("codec_type") == "video"), None)
    audio = next((s for s in streams if s.get("codec_type") == "audio"), None)
    if not video or not audio:
        raise RuntimeError(f"{path.name}: both video and audio streams are required.")
    width, height = int(video.get("width", 0)), int(video.get("height", 0))
    if not width or not height:
        raise RuntimeError(f"{path.name}: invalid video dimensions.")
    if expected_format == "short" and height <= width:
        raise RuntimeError(f"{path.name}: short video must be portrait, got {width}x{height}.")
    if expected_format == "long" and width <= height:
        raise RuntimeError(f"{path.name}: long video must be landscape, got {width}x{height}.")
    duration = float(data.get("format", {}).get("duration", 0))
    if duration <= 0 or abs(duration - expected_duration) > max(5.0, expected_duration * 0.03):
        raise RuntimeError(
            f"{path.name}: duration mismatch (manifest {expected_duration:.2f}s, file {duration:.2f}s)."
        )
    if expected_format == "short" and not 40 <= duration <= 70:
        raise RuntimeError(f"{path.name}: short duration outside 40–70 seconds.")
    if expected_format == "long" and not 210 <= duration <= 480:
        raise RuntimeError(f"{path.name}: long duration outside 210–480 seconds.")
    print(
        f"VALIDATED: {path.name} | {width}x{height} | "
        f"{duration:.2f}s | audio=yes | bytes={path.stat().st_size}",
        flush=True,
    )


def save_state(state: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    temp = STATE.with_suffix(".json.tmp")
    temp.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.replace(STATE)


def main() -> None:
    if pipeline.DRY_RUN:
        raise SystemExit("Refusing to upload while DRY_RUN=1.")
    required = ("YT_CLIENT_ID", "YT_CLIENT_SECRET", "YT_REFRESH_TOKEN")
    missing = [key for key in required if not os.getenv(key)]
    if missing:
        raise SystemExit("Missing YouTube OAuth secrets: " + ", ".join(missing))
    if not MANIFEST.is_file():
        raise SystemExit("queue/manifest.json is missing.")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    items = manifest.get("items")
    if not isinstance(items, list):
        raise SystemExit("queue/manifest.json must contain an items list.")

    requested = [x.strip() for x in os.getenv("QUEUE_VIDEO_IDS", "").split(",") if x.strip()]
    if not requested:
        raise SystemExit("QUEUE_VIDEO_IDS must contain at least one exact queue item ID.")
    if len(requested) != len(set(requested)):
        raise SystemExit("Duplicate IDs were supplied.")
    by_id = {str(item.get("id", "")): item for item in items if isinstance(item, dict)}
    unknown = [video_id for video_id in requested if video_id not in by_id]
    if unknown:
        raise SystemExit("Unknown queue item IDs: " + ", ".join(unknown))

    queue_state = {"published": {}}
    if STATE.is_file():
        queue_state = json.loads(STATE.read_text(encoding="utf-8"))
    published = queue_state.setdefault("published", {})

    for video_id in requested:
        if video_id in published:
            existing = published[video_id]
            youtube_id = str(existing.get("youtube_id", "")) if isinstance(existing, dict) else ""
            if youtube_id:
                print(f"ALREADY_PUBLISHED: {video_id} | https://youtu.be/{youtube_id}", flush=True)
                continue
            raise RuntimeError(f"{video_id} is marked published but has no YouTube ID; manual review required.")

        item = by_id[video_id]
        relpath = str(item.get("file") or "").strip()
        path = (ROOT / relpath).resolve()
        if ROOT.resolve() not in path.parents or path.suffix.lower() != ".mp4":
            raise RuntimeError(f"{video_id}: unsafe or non-MP4 queue path.")
        if not path.is_file() or path.stat().st_size < 100_000:
            raise RuntimeError(f"{video_id}: finished MP4 file is missing or too small.")

        fmt = str(item.get("format") or "").lower()
        if fmt not in {"short", "long"}:
            raise RuntimeError(f"{video_id}: format must be short or long.")
        expected_duration = float(item.get("duration_seconds") or 0)
        if expected_duration <= 0:
            raise RuntimeError(f"{video_id}: manifest duration is missing.")
        probe_video(path, fmt, expected_duration)

        work = {
            "uid": video_id,
            "kind": str(item.get("kind") or "movie"),
            "title_ar": str(item.get("title_ar") or item.get("title") or "").strip(),
            "title_en": str(item.get("title_en") or "").strip(),
            "release": str(item.get("release") or ""),
            "genres": item.get("genres") or [],
            "facts": item.get("facts") or [],
            "article_url": str(item.get("article_url") or ""),
            "source": str(item.get("source") or "VibeCritic"),
        }
        if work["kind"] not in {"movie", "tv", "game"} or not (work["title_ar"] or work["title_en"]):
            raise RuntimeError(f"{video_id}: invalid work metadata.")
        plan = {
            "format": fmt,
            "title": str(item.get("youtube_title") or work["title_ar"] or work["title_en"]),
            "description": str(item.get("description") or "محتوى من VibeCritic."),
            "hashtags": item.get("hashtags") or ["VibeCritic", "مراجعات"],
        }

        print(f"UPLOADING: {video_id} | {plan['title']} | privacy={pipeline.PRIVACY}", flush=True)
        youtube_id = pipeline.upload(path, work, plan)
        if not youtube_id:
            raise RuntimeError(f"{video_id}: YouTube returned no video ID.")
        published[video_id] = {
            "youtube_id": youtube_id,
            "published_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "file": relpath,
        }
        save_state(queue_state)
        print(f"PUBLISHED: {video_id} | https://youtu.be/{youtube_id}", flush=True)

    print("QUEUE_BATCH_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
