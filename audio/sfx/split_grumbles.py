"""
split_grumbles.py
Splits grumbles_raw.wav into individual grumble clips by detecting silence.

Tune the constants below if the split points are off:
  SILENCE_THRESHOLD  — amplitude (0-32767) below which a sample counts as silence
  MIN_SILENCE_SECS   — a gap must be at least this long to split two clips
  PAD_SECS           — silence padding kept before and after each clip
  MIN_CLIP_SECS      — clips shorter than this are discarded (noise / artefacts)
"""

import wave, struct, os, sys

# ── Tunables ──────────────────────────────────────────────────────────────────
SILENCE_THRESHOLD = 800      # 16-bit peak amplitude treated as silence
MIN_SILENCE_SECS  = 0.08     # 80 ms of quiet = clip boundary
PAD_SECS          = 0.04     # 40 ms of breathing room on each side
MIN_CLIP_SECS     = 0.10     # discard anything shorter than 100 ms
# ─────────────────────────────────────────────────────────────────────────────

SRC  = os.path.join(os.path.dirname(__file__), "grumbles_raw.wav")
OUT  = os.path.join(os.path.dirname(__file__), "grumbles")

os.makedirs(OUT, exist_ok=True)

with wave.open(SRC) as wf:
    rate       = wf.getframerate()
    sw         = wf.getsampwidth()
    ch         = wf.getnchannels()
    n_frames   = wf.getnframes()
    raw        = wf.readframes(n_frames)

# Decode to list of absolute amplitudes (mono 16-bit signed).
samples = [abs(struct.unpack_from("<h", raw, i)[0]) for i in range(0, len(raw), sw)]

min_silence = int(MIN_SILENCE_SECS * rate)
pad         = int(PAD_SECS         * rate)
min_clip    = int(MIN_CLIP_SECS    * rate)

# ── Find active regions ───────────────────────────────────────────────────────
# Walk the sample list and collect (start, end) frame pairs for each clip.
regions = []
in_clip  = False
start    = 0
silence  = 0

for i, amp in enumerate(samples):
    if amp > SILENCE_THRESHOLD:
        if not in_clip:
            start   = i
            in_clip = True
        silence = 0
    else:
        if in_clip:
            silence += 1
            if silence >= min_silence:
                regions.append((start, i - silence))
                in_clip = False
                silence = 0

if in_clip:
    regions.append((start, len(samples)))

# ── Apply padding and minimum-length filter ───────────────────────────────────
clipped = []
for s, e in regions:
    s = max(0, s - pad)
    e = min(len(samples), e + pad)
    if (e - s) >= min_clip:
        clipped.append((s, e))

print(f"Found {len(clipped)} clip(s).  Writing to {OUT}/")

# ── Write output files ────────────────────────────────────────────────────────
for idx, (s, e) in enumerate(clipped, start=1):
    out_path = os.path.join(OUT, f"grumble_{idx:02d}.wav")
    frames   = raw[s * sw : e * sw]
    with wave.open(out_path, "w") as wout:
        wout.setnchannels(ch)
        wout.setsampwidth(sw)
        wout.setframerate(rate)
        wout.writeframes(frames)
    dur = (e - s) / rate
    print(f"  grumble_{idx:02d}.wav  {s/rate:.2f}s – {e/rate:.2f}s  ({dur:.2f}s)")

print("Done.")
