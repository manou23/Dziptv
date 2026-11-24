# Free API Evaluation — VibeCritic Video

**Review date:** 2026-11-24  
**Scope:** temporary research and testing only. This document is not a permanent provider commitment.

## Sources reviewed

- [OuterSpacee/free-ai-apis](https://github.com/OuterSpacee/free-ai-apis) — broad directory including a video-generation section.
- [IdoY12/awesome-free-ai-apis](https://github.com/IdoY12/awesome-free-ai-apis) — focuses on renewable free tiers, checks provider documentation, and records privacy/commercial-use caveats.
- [surendranb/free-inference](https://github.com/surendranb/free-inference) — frequently updated provider/model catalog and machine-readable data.
- [pacocartones/free-llm-api-hub](https://github.com/pacocartones/free-llm-api-hub) — dated provider records for text, image, and speech; explicitly does not track video-generation APIs.

Directories are discovery aids, not guarantees. Every provider must be rechecked against its own current pricing, API, and terms pages before use.

## Temporary candidates

| Pipeline stage | Candidate | Current decision | Reason / caveat |
|---|---|---|---|
| Script generation | Google Gemini API | Keep as primary candidate | Has a limited free API tier. Free-tier content may be used to improve Google's products. Model quotas vary. |
| Script fallback | BazaarLink `auto:free` | Keep as free fallback candidate | Free model quota is dynamic. The request sends `X-Free-Fallback: false` so quota exhaustion fails instead of silently switching to paid routing. Confirm actual resolved model and usage after a test. |
| Script fallback | Direct DeepSeek API | Disabled by default | Direct API usage is token-billed. It is not the same as free DeepSeek chat or a free model routed through BazaarLink. |
| Voice | Edge TTS | Keep for now | Existing speech path; no separate paid API key is required by this project. Availability and voice quality still need testing. |
| Scene images | Pollinations | Temporary candidate | Existing keyless image endpoint. No production SLA is assumed; use the local abstract-art fallback if it fails. |
| AI video generation | Kling API | Do not use as a free API | Current developer API onboarding requires purchasing video-generation resource packages. Free credits in the consumer app do not establish free API access. |
| AI video generation | Replicate | Do not use for ongoing free production | The listed $5 is a one-time signup credit, not a renewable free tier. |
| AI video generation | Hugging Face Inference Providers | Do not use for free production | Current pricing documentation lists no included monthly inference credits for Free users; additional usage is pay-as-you-go. |

## Current conclusion

No verified, permanent, hosted, $0 video-generation API suitable for unattended GitHub Actions production was found in these directories. The current renderer therefore produces an MP4 from generated/stored still images, Arabic narration, captions, and FFmpeg; it does **not** create moving AI-generated scenes.

## Safety rules for the trial

1. Never use keys copied from public repositories or other people.
2. Keep all credentials in GitHub Actions Secrets, never in source files.
3. Keep paid DeepSeek and paid OpenAI paths disabled unless the owner explicitly changes that policy.
4. Keep BazaarLink's free-only fallback header enabled; a quota limit must fail closed, not bill.
5. Manual tests on the development branch run with `DRY_RUN=1` and create preview artifacts only. Scheduled publishing behavior remains unchanged on the default branch.
6. Do not select a permanent provider until a real API call, generated artifact, quality check, quota behavior, and applicable usage terms have been verified.

## Selection scorecard for the eventual private registry

- Confirmed $0 API access (not a web-app free plan or trial credit)
- No card / no prepaid balance required
- No paid fallback after quota exhaustion
- Usable from GitHub Actions without browser automation
- Output quality for Arabic narration and cinematic scenes
- Clear rate limits, commercial-use terms, and data-retention policy
- Stable API endpoint and recoverable error behavior
