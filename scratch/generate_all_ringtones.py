import wave
import struct
import math
import os

SAMPLE_RATE = 44100
OUTPUT_DIR = r"android\app\src\main\res\raw"

def clamp(val, min_val=-1.0, max_val=1.0):
    return max(min_val, min(max_val, val))

def save_wav(filename, samples):
    filepath = os.path.join(OUTPUT_DIR, filename)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)        # mono
        wf.setsampwidth(2)        # 16-bit
        wf.setframerate(SAMPLE_RATE)
        int_samples = [int(clamp(s) * 32767) for s in samples]
        raw_data = struct.pack(f'<{len(int_samples)}h', *int_samples)
        wf.writeframes(raw_data)
    print(f"Generated {filename}: {len(samples)/SAMPLE_RATE:.2f}s, {len(raw_data)} bytes")

# 1. Simple Ping: Clean 880Hz sine with quick exponential decay
def gen_simple_ping():
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    samples = []
    freq = 880.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-10.0 * t)
        val = 0.7 * math.sin(2 * math.pi * freq * t) * env
        samples.append(val)
    save_wav("sound_simple_ping.wav", samples)

# 2. Bubble Pop: Rising chirp 450Hz -> 950Hz with rounded pop envelope
def gen_bubble_pop():
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 450.0 + (950.0 - 450.0) * (t / dur) ** 1.8
        env = math.sin(math.pi * (t / dur)) ** 1.5
        val = 0.75 * math.sin(2 * math.pi * f * t) * env
        samples.append(val)
    save_wav("sound_bubble_pop.wav", samples)

# 3. Gentle Glass Ding: 1320Hz fundamental with harmonic overtones and long tail
def gen_gentle_ding():
    dur = 0.75
    n = int(SAMPLE_RATE * dur)
    samples = []
    f1, f2, f3 = 1318.5, 2637.0, 3951.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env1 = math.exp(-5.0 * t)
        env2 = math.exp(-8.0 * t)
        env3 = math.exp(-12.0 * t)
        val = (0.55 * math.sin(2 * math.pi * f1 * t) * env1 +
               0.25 * math.sin(2 * math.pi * f2 * t) * env2 +
               0.10 * math.sin(2 * math.pi * f3 * t) * env3)
        samples.append(val)
    save_wav("sound_gentle_ding.wav", samples)

# 4. Radar Alert: Dual tactical sonar pulses (950Hz & 1400Hz) repeated twice
def gen_radar_beep():
    dur = 0.85
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        cycle_t = t % 0.42
        if cycle_t < 0.15:
            env = math.sin(math.pi * (cycle_t / 0.15))
            val = (0.5 * math.sin(2 * math.pi * 950 * t) +
                   0.4 * math.sin(2 * math.pi * 1420 * t)) * env
        else:
            val = 0.0
        samples.append(val)
    save_wav("sound_radar_beep.wav", samples)

# 5. Electronic Buzzer: Sharp sawtooth/square alert buzz bursts
def gen_electronic_buzz():
    dur = 0.90
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        burst_idx = int(t / 0.18)
        burst_t = t % 0.18
        if burst_idx < 4 and burst_t < 0.12:
            # Bandlimited rich buzz (f0=350Hz)
            f0 = 350.0
            buzz = (0.40 * math.sin(2 * math.pi * f0 * t) +
                    0.25 * math.sin(2 * math.pi * 3 * f0 * t) +
                    0.15 * math.sin(2 * math.pi * 5 * f0 * t) +
                    0.10 * math.sin(2 * math.pi * 7 * f0 * t))
            env = min(1.0, burst_t / 0.01) * max(0.0, 1.0 - (burst_t - 0.09) / 0.03)
            val = buzz * env
        else:
            val = 0.0
        samples.append(val)
    save_wav("sound_electronic_buzz.wav", samples)

# 6. Caution Staccato: 3 fast urgent warning beeps (1050Hz)
def gen_caution_staccato():
    dur = 0.75
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        beep_idx = int(t / 0.16)
        beep_t = t % 0.16
        if beep_idx < 3 and beep_t < 0.10:
            env = math.sin(math.pi * (beep_t / 0.10))
            val = (0.6 * math.sin(2 * math.pi * 1046.5 * t) +
                   0.25 * math.sin(2 * math.pi * 2093.0 * t)) * env
        else:
            val = 0.0
        samples.append(val)
    save_wav("sound_caution_staccato.wav", samples)

# 7. Long Beacon: Extended 3-second harmonic acoustic alarm sequence
def gen_continuous_beacon():
    dur = 2.8
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        cycle_t = t % 0.70
        if cycle_t < 0.45:
            mod = 1.0 + 0.15 * math.sin(2 * math.pi * 14 * cycle_t)
            f = 780.0
            env = math.sin(math.pi * (cycle_t / 0.45))
            val = 0.7 * math.sin(2 * math.pi * f * t) * mod * env
        else:
            val = 0.0
        samples.append(val)
    save_wav("sound_continuous_beacon.wav", samples)

# 8. Extended Klaxon: 2.8-second dual-tone industrial horn alternating 520Hz / 650Hz
def gen_extended_klaxon():
    dur = 2.8
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        period = int(t / 0.35) % 2
        f = 523.25 if period == 0 else 659.25
        # Rich brass horn harmonics
        val = (0.45 * math.sin(2 * math.pi * f * t) +
               0.25 * math.sin(2 * math.pi * 2 * f * t) +
               0.15 * math.sin(2 * math.pi * 3 * f * t))
        samples.append(val * 0.8)
    save_wav("sound_extended_klaxon.wav", samples)

# 9. Persistent Ring: 3.0-second oscillating ringing chime cycle
def gen_persistent_loop():
    dur = 3.0
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        rep_t = t % 0.50
        if rep_t < 0.38:
            env = math.exp(-4.5 * rep_t)
            f1, f2 = 1174.6, 1760.0
            val = (0.5 * math.sin(2 * math.pi * f1 * t) +
                   0.3 * math.sin(2 * math.pi * f2 * t)) * env
        else:
            val = 0.0
        samples.append(val)
    save_wav("sound_persistent_loop.wav", samples)

# 10. Morning Celesta: 4-note ascending musical arpeggio (C5, E5, G5, C6)
def gen_celesta_harmony():
    notes = [523.25, 659.25, 783.99, 1046.50]
    note_dur = 0.32
    dur = len(notes) * note_dur + 0.5
    n = int(SAMPLE_RATE * dur)
    samples = [0.0] * n
    for idx, freq in enumerate(notes):
        start_idx = int(idx * note_dur * SAMPLE_RATE)
        note_len = int(0.7 * SAMPLE_RATE)
        for i in range(note_len):
            if start_idx + i < n:
                t = i / SAMPLE_RATE
                env = math.exp(-5.0 * t)
                val = (0.5 * math.sin(2 * math.pi * freq * t) +
                       0.2 * math.sin(2 * math.pi * 2 * freq * t) +
                       0.08 * math.sin(2 * math.pi * 3 * freq * t)) * env
                samples[start_idx + i] += val
    save_wav("sound_celesta_harmony.wav", samples)

# 11. Zen Harp: Soothing pentatonic harp sequence (E4, G4, A4, B4, D5)
def gen_zen_harp():
    notes = [329.63, 392.00, 440.00, 493.88, 587.33]
    note_dur = 0.28
    dur = len(notes) * note_dur + 0.6
    n = int(SAMPLE_RATE * dur)
    samples = [0.0] * n
    for idx, freq in enumerate(notes):
        start_idx = int(idx * note_dur * SAMPLE_RATE)
        note_len = int(0.8 * SAMPLE_RATE)
        for i in range(note_len):
            if start_idx + i < n:
                t = i / SAMPLE_RATE
                env = math.exp(-4.0 * t)
                val = (0.55 * math.sin(2 * math.pi * freq * t) +
                       0.25 * math.sin(2 * math.pi * 2 * freq * t)) * env
                samples[start_idx + i] += val
    save_wav("sound_zen_harp.wav", samples)

# 12. Breeze Melody: Smooth acoustic flourish (A5, B5, C#6)
def gen_flute_breeze():
    notes = [880.00, 987.77, 1108.73]
    note_dur = 0.36
    dur = len(notes) * note_dur + 0.5
    n = int(SAMPLE_RATE * dur)
    samples = [0.0] * n
    for idx, freq in enumerate(notes):
        start_idx = int(idx * note_dur * SAMPLE_RATE)
        note_len = int(0.7 * SAMPLE_RATE)
        for i in range(note_len):
            if start_idx + i < n:
                t = i / SAMPLE_RATE
                env = math.sin(min(math.pi / 2, t * 15)) * math.exp(-3.5 * t)
                val = (0.55 * math.sin(2 * math.pi * freq * t) +
                       0.15 * math.sin(2 * math.pi * 3 * freq * t)) * env
                samples[start_idx + i] += val
    save_wav("sound_flute_breeze.wav", samples)

# 13. Soft Woodblock: Warm mellow low-volume acoustic tap (amplitude 0.35)
def gen_soft_woodblock():
    dur = 0.35
    n = int(SAMPLE_RATE * dur)
    samples = []
    freq = 680.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-18.0 * t)
        val = 0.35 * (math.sin(2 * math.pi * freq * t) +
                      0.3 * math.sin(2 * math.pi * 2.3 * freq * t)) * env
        samples.append(val)
    save_wav("sound_soft_woodblock.wav", samples)

# 14. Whisper Chime: Delicate low-intensity crystal tone (amplitude 0.30)
def gen_whisper_chime():
    dur = 0.85
    n = int(SAMPLE_RATE * dur)
    samples = []
    freq = 1567.98 # G6
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-4.5 * t)
        val = 0.30 * math.sin(2 * math.pi * freq * t) * env
        samples.append(val)
    save_wav("sound_whisper_chime.wav", samples)

# 15. Warm Ambient Glow: Soft resonant sine bell with warm pad (amplitude 0.32)
def gen_warm_ambient():
    dur = 1.2
    n = int(SAMPLE_RATE * dur)
    samples = []
    f1, f2 = 440.0, 554.37 # A4, C#5
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-3.2 * t)
        val = 0.32 * (0.6 * math.sin(2 * math.pi * f1 * t) +
                      0.4 * math.sin(2 * math.pi * f2 * t)) * env
        samples.append(val)
    save_wav("sound_warm_ambient.wav", samples)

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Generating 15 ringtone variants...")
    gen_simple_ping()
    gen_bubble_pop()
    gen_gentle_ding()
    gen_radar_beep()
    gen_electronic_buzz()
    gen_caution_staccato()
    gen_continuous_beacon()
    gen_extended_klaxon()
    gen_persistent_loop()
    gen_celesta_harmony()
    gen_zen_harp()
    gen_flute_breeze()
    gen_soft_woodblock()
    gen_whisper_chime()
    gen_warm_ambient()
    print("All 15 ringtones successfully created!")
