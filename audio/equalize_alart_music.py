"""
equalize_alart_music.py
Measures the RMS loudness of the exploration tracks (BackgroundMusic),
then boosts the alart tracks to match that average level.

Uses ffmpeg for decoding (handles both OGG and MP3) and for applying gain.
Re-encodes alart MP3s in-place at 192k; adjust ALART_BITRATE if needed.
"""

import subprocess, struct, math, os, shutil, tempfile

EXPLORATION_DIR = os.path.join(os.path.dirname(__file__), "music")
ALART_FILES     = [
    os.path.join(EXPLORATION_DIR, "bgm_alart_01.mp3"),
    os.path.join(EXPLORATION_DIR, "bgm_alart_02.mp3"),
]
ALART_BITRATE   = "192k"

# ── Helpers ───────────────────────────────────────────────────────────────────

def decode_to_pcm(path: str) -> list[int]:
    """Decode any audio file to mono 16-bit signed PCM samples via ffmpeg."""
    result = subprocess.run(
        ["ffmpeg", "-i", path, "-f", "s16le", "-ac", "1", "-ar", "44100", "-"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
    raw = result.stdout
    count = len(raw) // 2
    return list(struct.unpack(f"<{count}h", raw))


def rms(samples: list[int]) -> float:
    if not samples:
        return 0.0
    return math.sqrt(sum(s * s for s in samples) / len(samples))


def rms_to_db(r: float) -> float:
    return 20.0 * math.log10(r / 32768.0) if r > 0 else -96.0


def apply_gain_db(src: str, dest: str, gain_db: float) -> None:
    """Re-encode src to dest with the given dB gain applied."""
    subprocess.run(
        ["ffmpeg", "-y", "-i", src,
         "-af", f"volume={gain_db:.2f}dB",
         "-b:a", ALART_BITRATE, dest],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        check=True
    )

# ── Measure exploration tracks ────────────────────────────────────────────────

exploration_files = sorted(
    os.path.join(EXPLORATION_DIR, f)
    for f in os.listdir(EXPLORATION_DIR)
    if f.endswith(".ogg")
)

print(f"Measuring {len(exploration_files)} exploration track(s)...")
exploration_rms_db = []
for path in exploration_files:
    samples = decode_to_pcm(path)
    r       = rms(samples)
    db      = rms_to_db(r)
    exploration_rms_db.append(db)
    print(f"  {os.path.basename(path):45s}  {db:+.1f} dBFS RMS")

target_db = sum(exploration_rms_db) / len(exploration_rms_db)
print(f"\nExploration average RMS: {target_db:+.1f} dBFS")

# ── Measure and boost alart tracks ───────────────────────────────────────────

print(f"\nMeasuring and boosting {len(ALART_FILES)} alart track(s)...")
for path in ALART_FILES:
    if not os.path.exists(path):
        print(f"  SKIP {os.path.basename(path)} — file not found")
        continue
    samples  = decode_to_pcm(path)
    r        = rms(samples)
    db       = rms_to_db(r)
    gain     = target_db - db
    print(f"  {os.path.basename(path):45s}  {db:+.1f} dBFS  gain {gain:+.1f} dB")

    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        apply_gain_db(path, tmp_path, gain)
        shutil.move(tmp_path, path)
    except Exception as e:
        os.unlink(tmp_path)
        print(f"    ERROR: {e}")

print("\nDone.")
