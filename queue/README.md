# VibeCritic Video Queue

Place finished, reviewed MP4 files in this directory (or a subdirectory) and register each one in `manifest.json`.

Each item supports:
- `id`: unique stable identifier; never reuse it.
- `file`: repository-relative MP4 path, e.g. `queue/shorts/review-example.mp4`.
- `title_ar` / `title_en`: accurate work title.
- `kind`: `movie`, `tv`, or `game`.
- `format`: `short` or `long`.
- `youtube_title`, `description`, `hashtags`, `article_url`: publishing metadata.

The scheduled workflow publishes at most one unprocessed queue item per run. A successful YouTube upload is recorded in `state/queue.json`; failed uploads are not marked as published and can be retried. Manual workflow runs remain dry-runs and copy the selected MP4 into the downloadable artifact instead of publishing.

Only add finished MP4s with their narration, rights-cleared visuals, and checked metadata. Do not add placeholders or unreviewed test videos. Keep files reasonably sized for GitHub repository limits.
