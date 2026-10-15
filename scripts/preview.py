#!/usr/bin/env python3
"""Aperçu du design RunCatPlus : chat (3 phases de foulée) + anneaux de quota."""
import math
from PIL import Image, ImageDraw

S = 4  # supersampling
W, H = 720 * S, 160 * S
img = Image.new("RGB", (W, H), (30, 30, 34))
d = ImageDraw.Draw(img)

UNIT = 4.4 * S  # échelle « unit » du Canvas Swift


def draw_cat(x0, y0, phase, speed):
    u = UNIT
    ground_y = y0 + 19 * u
    d.line([(x0 + u, ground_y), (x0 + 21 * u, ground_y)], fill=(150, 150, 155), width=2 * S)
    angle = phase * 2 * math.pi
    bob = abs(math.sin(angle)) * (0.4 + speed * 0.5) * u
    lean = speed * 0.8 * u
    black = (235, 235, 240)

    # pattes (sous le corps)
    legs = [(7.8, 0), (9.4, math.pi), (13.2, math.pi), (14.8, 0)]
    for lx, off in legs:
        a = angle + off
        sx = math.sin(a) * (1.8 + speed * 0.8) * u
        lift = max(0, math.cos(a)) * (2.2 + speed * 1.2) * u
        hip = (x0 + lx * u, y0 + 15 * u - bob)
        foot = (x0 + lx * u + sx, y0 + 19 * u - lift)
        knee = ((hip[0] + foot[0]) / 2 - lift * 0.35, (hip[1] + foot[1]) / 2)
        # quadratique échantillonnée
        pts = []
        for t in [i / 8 for i in range(9)]:
            px = (1 - t) ** 2 * hip[0] + 2 * (1 - t) * t * knee[0] + t ** 2 * foot[0]
            py = (1 - t) ** 2 * hip[1] + 2 * (1 - t) * t * knee[1] + t ** 2 * foot[1]
            pts.append((px, py))
        d.line(pts, fill=black, width=2 * S)

    # corps (plus long, englobe le cou)
    d.ellipse([x0 + 5.5 * u, y0 + 10 * u - bob, x0 + 17.2 * u, y0 + 16 * u - bob], fill=black)
    # queue dressée, ondulante (2 segments)
    sway = math.sin(angle) * 1.6 * u
    base = (x0 + 5.8 * u, y0 + 12.0 * u - bob)
    mid = (x0 + 3.6 * u, y0 + 10.0 * u - bob + sway * 0.4)
    tip = (x0 + 3.0 * u, y0 + 6.6 * u - bob + sway)
    d.line([base, mid, tip], fill=black, width=3 * S, joint="curve")
    # tête + oreilles (tête baissée sur le corps, pas détachée)
    hx, hy = x0 + 16.9 * u, y0 + 9.9 * u - bob - lean * 0.3
    r = 2.7 * u
    d.ellipse([hx - r, hy - r, hx + r, hy + r], fill=black)
    tilt = speed * 0.5
    for sgn in (-1, 1):
        bx = hx + sgn * 1.35 * u
        d.polygon([(bx - 0.85 * u, hy - 1.7 * u),
                   (bx + sgn * tilt * u, hy - 4.4 * u + tilt * u),
                   (bx + 0.85 * u, hy - 1.7 * u)], fill=black)


def draw_ring(x0, y0, size, pct_out, pct_in, countdown, brand):
    u = size / 2
    cx, cy = x0 + u, y0 + u + 3 * S
    ro = u - 1.2 * S
    ri = ro * 0.62
    # pastille de marque à midi
    dr = 1.6 * S
    d.ellipse([cx - dr, cy - ro - dr - 1 * S, cx + dr, cy - ro + dr - 1 * S], fill=brand)
    # fonds
    d.ellipse([cx - ro, cy - ro, cx + ro, cy + ro], outline=(70, 70, 76), width=2 * S)
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], outline=(60, 60, 66), width=1 * S)
    # arcs
    for radius, pct, wd in ((ro, pct_out, 2 * S), (ri, pct_in, 1 * S)):
        col = (90, 200, 120) if pct < 60 else ((240, 170, 60) if pct < 85 else (235, 80, 70))
        start = -90
        end = -90 + pct * 3.6
        d.arc([cx - radius, cy - radius, cx + radius, cy + radius],
              start=start, end=end, fill=col, width=wd)
    # compte à rebours
    try:
        from PIL import ImageFont
        f = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", int(6.4 * S))
    except Exception:
        f = ImageFont.load_default()
    bbox = d.textbbox((0, 0), countdown, font=f)
    d.text((cx - (bbox[2] - bbox[0]) / 2, cy - (bbox[3] - bbox[1]) / 2 - bbox[1]), countdown,
           fill=(230, 230, 235), font=f)


# --- composition ---
strip_y = 30 * S
# chat à 3 phases (repos / course moyenne / sprint)
draw_cat(40 * S, strip_y, 0.0, 0.1)
draw_cat(180 * S, strip_y, 0.25, 0.5)
draw_cat(320 * S, strip_y, 0.5, 1.0)

# anneaux (valeurs réelles)
CL = (217, 119, 87)   # coral Claude
KI = (59, 130, 245)   # bleu Kimi
draw_ring(500 * S, 30 * S, 20 * S, 29, 18, "4j2h", CL)
draw_ring(580 * S, 30 * S, 20 * S, 22, 1, "4j4h", KI)

img = img.resize((720, 160), Image.LANCZOS)
img.save("design_preview.png")
print("design_preview.png OK")
