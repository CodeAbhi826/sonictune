# Project rules for AI agents

## Naming rule (always)

- Never use the names of any AI or other GitHub projects — e.g. "archivetune",
  "simpmusic", "musify", or any similar third-party music-app/AI project name —
  in commit messages, push messages, or anywhere in this repository.
- Always refer to this project only as "SonicTune" or generically ("the app",
  "this project"). If a task has no SonicTune-specific name, use a generic
  term instead of borrowing another project's name.

## Request Limit / Rate Limit Rule

- **Max 30 total worker requests**: Do not exceed 30 API/tool/worker requests in a single sequence or session (to stay safely under the worker local limit of 32/32 and avoid `ResourceExhausted` errors). Always stop, consolidate, or pause before reaching 30 requests.

