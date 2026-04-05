# Register Subtree Guidance

This directory owns the reproducible OpenAI registration/import workflow.

## Operating rules

- Keep [`agentic-openai-workflow-log.md`](./agentic-openai-workflow-log.md) current whenever you change scripts, docs, fallback paths, or verification steps in this subtree.
- Preserve historical run notes in that log; append new runs instead of overwriting earlier evidence.
- Prefer stable local automation over observation-heavy recovery. For Hide My Email creation, the default path is the pure Accessibility-based Swift flow, not OCR or screenshot-driven clicking.
- If a temporary visual debugging aid is needed, use it only to diagnose the issue, then convert the learned path back into code before considering the task complete.
- Do not switch the user's active Codexbar account as part of import verification unless they explicitly ask.
- Never print OAuth tokens, refresh tokens, or ID tokens in logs, docs, or commit messages.

## Local artifact hygiene

- Do not commit runtime artifacts such as `.playwright-cli/`, `.omx/`, `.ufoo/`, screenshots, or ad hoc scratch files.
- Prefer short `PLAYWRIGHT_SESSION` names on this Mac. Long names can overflow the local daemon socket path and fail before browser launch.
