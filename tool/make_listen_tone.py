#!/usr/bin/env python3
"""نغمة «سامعك» — نغمة قصيرة هادية لحظة ما المايك يتفتح.

`speech_to_text` على iOS بيدوّر على `assets/sounds/speech_to_text_listening.m4r`
في أصول التطبيق، ولو لقاها بيشغّلها **هو** وبعدين بس بيقول «listening» —
فالنغمة بتيجي في لحظة فتح المايك بالظبط، ومن غير ما تتخانق مع مشغّلنا على
جلسة الصوت.

نوتتين طالعين (C6 ← E6، ٩٠ + ١١٠ ملّي)، حواف ناعمة، عند −18 dBFS: إشارة مش
جرس. بتاعتنا — مفيش ترخيص نتابعه.

    python3 tool/make_listen_tone.py
    afconvert -f m4af -d aac /tmp/listen_tone.wav assets/sounds/speech_to_text_listening.m4r
"""
import math
import struct
import wave

RATE = 44100
AMP = 10 ** (-18 / 20)


def note(freq, ms):
    n = int(RATE * ms / 1000)
    fade = int(RATE * 0.012)
    out = []
    for i in range(n):
        env = min(1.0, i / fade, (n - i) / fade)
        out.append(AMP * env * math.sin(2 * math.pi * freq * i / RATE))
    return out


samples = note(1046.5, 90) + [0.0] * int(RATE * 0.015) + note(1318.5, 110)
with wave.open('/tmp/listen_tone.wav', 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b''.join(struct.pack('<h', int(s * 32767)) for s in samples))
print(f'{len(samples) / RATE * 1000:.0f} ms')
