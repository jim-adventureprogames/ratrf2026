"""
normalize_grumbles.py
Peak-normalizes every .wav in the grumbles/ folder in-place.

Each file is scaled so its loudest sample hits TARGET_DBFS.
-1.0 dBFS leaves a tiny headroom; raise it toward 0.0 for maximum loudness.
"""

import wave, struct, os

TARGET_DBFS = -1.0   # target peak level in dBFS (0.0 = absolute maximum)

DIR = os.path.join(os.path.dirname(__file__), "grumbles")

def normalize(path: str) -> None:
    with wave.open(path) as wf:
        ch   = wf.getnchannels()
        sw   = wf.getsampwidth()
        rate = wf.getframerate()
        n    = wf.getnframes()
        raw  = wf.readframes(n)

    if sw != 2:
        print(f"  SKIP {os.path.basename(path)} — only 16-bit supported")
        return

    fmt     = f"<{len(raw)//2}h"
    samples = list(struct.unpack(fmt, raw))

    peak = max(abs(s) for s in samples)
    if peak == 0:
        print(f"  SKIP {os.path.basename(path)} — silent file")
        return

    target_peak = 32767 * (10.0 ** (TARGET_DBFS / 20.0))
    gain        = target_peak / peak

    scaled = [max(-32768, min(32767, int(s * gain))) for s in samples]

    out_raw = struct.pack(fmt, *scaled)

    with wave.open(path, "w") as wout:
        wout.setnchannels(ch)
        wout.setsampwidth(sw)
        wout.setframerate(rate)
        wout.writeframes(out_raw)

    print(f"  {os.path.basename(path)}  peak {peak}/32767  gain x{gain:.2f}  -> {TARGET_DBFS} dBFS")


wavs = sorted(f for f in os.listdir(DIR) if f.lower().endswith(".wav"))
print(f"Normalizing {len(wavs)} file(s) in {DIR}/")
for name in wavs:
    normalize(os.path.join(DIR, name))
print("Done.")
