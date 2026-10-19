# Reels workshop

This repo is where Claude edits the user's vertical Instagram reels (9:16, ~60 s) from long phone videos.

## Always
- Reply in **Russian**.
- Load the project skill **`reels`** (`.claude/skills/reels/SKILL.md`) before any editing work and follow it. Append what you learn to its "Lessons log".
- **Verify before delivering.** Claude can't hear audio, so prove quality with numbers and say which checks ran: DNSMOS (target OVRL ≥ 2.7, and better than raw), re-transcription anchor ratio, no clipping (true peak < −1 dBTP), loudness ≈ −14 LUFS, snapshot frames, caption sync, no dead air between cuts (> 0.5 s).
- Each project lives in `projects/<name>/` with `assets/source.mp4` (the user's original) and `edit.json` (cut list + caption texts). Generated files go to `projects/<name>/work/` and `projects/<name>/hf/` (git-ignored except `hf/index.html`, `hf/captions.json`).
- Final outputs: `projects/<name>/out/<name>.mp4` and a phone copy `<name>-phone.mp4` (< 30 MB: `-crf 22 -maxrate 3500k -bufsize 7000k`). Commit them (they are the deliverable) unless the user says otherwise.

## What the user cares about (from feedback)
1. **Studio-quality voice** — phone mic in a reverberant church hall. Plain denoise + EQ "sounds very bad". Use generative restoration (Resemble Enhance) — see skill §4.
2. **Captions exactly in sync** with the words (per-segment alignment, skill §5).
3. **No silences / dead air** between or inside cuts (tighten + split-pauses, skill §5).
4. Emotional moments (reactions, re-enactments) are the best material — keep them.
