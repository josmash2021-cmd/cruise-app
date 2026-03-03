"""
Generate a high-quality black 3D top-down car PNG sprite.
- 200x300 canvas, transparent background
- Uber-style 2.5D isometric: body, cabin, wheels, headlights, taillights
- All-black body with subtle highlight gradients for 3D depth
"""
from PIL import Image, ImageDraw, ImageFilter
import math, os

W, H = 200, 300
CX, CY = W // 2, H // 2

# Half extents
bw, bh = 78, 110

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# ── Helper: rounded_rect as polygon approximation ──
def rounded_rect_pts(cx, cy, hw, hh, r_tl, r_tr, r_br, r_bl, n=12):
    pts = []
    corners = [
        (cx - hw + r_tl, cy - hh + r_tl, r_tl, math.pi, 1.5 * math.pi),     # TL
        (cx + hw - r_tr, cy - hh + r_tr, r_tr, 1.5 * math.pi, 2 * math.pi),  # TR
        (cx + hw - r_br, cy + hh - r_br, r_br, 0, 0.5 * math.pi),            # BR
        (cx - hw + r_bl, cy + hh - r_bl, r_bl, 0.5 * math.pi, math.pi),      # BL
    ]
    for ccx, ccy, r, a0, a1 in corners:
        if r < 1:
            pts.append((ccx, ccy))
            continue
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            pts.append((ccx + r * math.cos(a), ccy + r * math.sin(a)))
    return pts

# ── 1. DROP SHADOW ──
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.ellipse([CX - bw - 18, CY - bh - 10, CX + bw + 18, CY + bh + 18],
           fill=(0, 0, 0, 70))
shadow = shadow.filter(ImageFilter.GaussianBlur(18))
img = Image.alpha_composite(img, shadow)
draw = ImageDraw.Draw(img)

# ── 2. WHEELS ──
ww, wh = 34, 42
wheel_positions = [
    (CX - int(bw * 0.88), CY - int(bh * 0.62)),  # front-left
    (CX + int(bw * 0.88), CY - int(bh * 0.62)),  # front-right
    (CX - int(bw * 0.88), CY + int(bh * 0.60)),  # rear-left
    (CX + int(bw * 0.88), CY + int(bh * 0.60)),  # rear-right
]
for wx, wy in wheel_positions:
    draw.ellipse([wx - ww//2, wy - wh//2, wx + ww//2, wy + wh//2],
                 fill=(17, 17, 17, 255))
    # rim
    rr = int(ww * 0.22)
    draw.ellipse([wx - rr, wy - rr, wx + rr, wy + rr],
                 fill=(100, 100, 100, 255))

# ── 3. BODY ──
r_top = int(bw * 0.72)
r_bot = int(bw * 0.40)
body_pts = rounded_rect_pts(CX, CY, bw, bh, r_top, r_top, r_bot, r_bot)
draw.polygon(body_pts, fill=(30, 30, 30, 255))

# Body gradient overlay (top-left highlight for 3D effect)
grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(grad)
# Lighter highlight in upper-left area
for i in range(60):
    alpha = int(25 * (1 - i / 60))
    r = bw - i
    if r < 5:
        break
    gd.ellipse([CX - int(bw * 0.8) - r, CY - int(bh * 0.9) - r,
                CX - int(bw * 0.8) + r, CY - int(bh * 0.9) + r],
               fill=(255, 255, 255, alpha))
# Mask gradient to body shape
body_mask = Image.new("L", (W, H), 0)
bmd = ImageDraw.Draw(body_mask)
bmd.polygon(body_pts, fill=255)
grad_clipped = Image.new("RGBA", (W, H), (0, 0, 0, 0))
grad_clipped.paste(grad, mask=body_mask)
img = Image.alpha_composite(img, grad_clipped)
draw = ImageDraw.Draw(img)

# Body border
draw.polygon(body_pts, outline=(80, 80, 80, 200))

# ── 3b. 3D DEPTH STRIPS ──
# Left side panel (darker strip)
depth_l = rounded_rect_pts(CX - bw - 5, CY, 5, int(bh * 0.77), 0, 0, 0, int(bw * 0.3))
draw.polygon(depth_l, fill=(0, 0, 0, 55))
# Right side panel
depth_r = rounded_rect_pts(CX + bw + 5, CY, 5, int(bh * 0.77), 0, 0, int(bw * 0.3), 0)
draw.polygon(depth_r, fill=(0, 0, 0, 38))
# Bottom face (bumper thickness)
bx1, by1 = CX - bw + 5, CY + bh + 1
bx2, by2 = CX + bw - 5, CY + bh + 14
draw.rounded_rectangle([bx1, by1, bx2, by2], radius=int(bw * 0.35),
                        fill=(0, 0, 0, 70))

# ── 4. CABIN / WINDSHIELD ──
cab_w = int(bw * 0.64)
cab_h = int(bh * 0.52)
cab_cy = CY - int(bh * 0.04)
cab_r_top = int(bw * 0.48)
cab_r_bot = int(bw * 0.22)
cabin_pts = rounded_rect_pts(CX, cab_cy, cab_w, cab_h, cab_r_top, cab_r_top, cab_r_bot, cab_r_bot)
draw.polygon(cabin_pts, fill=(13, 13, 13, 255))

# Glass sheen (left streak)
sheen_x = CX - int(bw * 0.56)
sheen_y = cab_cy - cab_h // 2 + 6
sheen_w = int(bw * 0.11)
sheen_h = int(cab_h * 0.50)
draw.rounded_rectangle([sheen_x, sheen_y, sheen_x + sheen_w, sheen_y + sheen_h],
                        radius=4, fill=(80, 80, 80, 45))

# ── 5. HEADLIGHTS ──
hl_y = CY - int(bh * 0.88)
for sign in [-1, 1]:
    hx = CX + sign * int(bw * 0.46)
    hw2, hh2 = int(bw * 0.19), 4
    draw.rounded_rectangle([hx - hw2, hl_y - hh2, hx + hw2, hl_y + hh2],
                            radius=3, fill=(255, 224, 130, 255))

# ── 6. TAILLIGHTS ──
tl_y = CY + int(bh * 0.88)
for sign in [-1, 1]:
    tx = CX + sign * int(bw * 0.44)
    tw2, th2 = int(bw * 0.18), 3
    draw.rounded_rectangle([tx - tw2, tl_y - th2, tx + tw2, tl_y + th2],
                            radius=2, fill=(239, 83, 80, 255))

# ── 7. ROOF HIGHLIGHT (subtle white gradient on cabin top) ──
roof_grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rgd = ImageDraw.Draw(roof_grad)
for i in range(30):
    alpha = int(18 * (1 - i / 30))
    r = cab_w - i
    if r < 2:
        break
    rgd.ellipse([CX - r, cab_cy - cab_h // 2 - r + 15,
                 CX + r, cab_cy - cab_h // 2 + r + 15],
                fill=(255, 255, 255, alpha))
cabin_mask = Image.new("L", (W, H), 0)
cmd = ImageDraw.Draw(cabin_mask)
cmd.polygon(cabin_pts, fill=255)
roof_clipped = Image.new("RGBA", (W, H), (0, 0, 0, 0))
roof_clipped.paste(roof_grad, mask=cabin_mask)
img = Image.alpha_composite(img, roof_clipped)

# ── SAVE ──
out_path = os.path.join(os.path.dirname(__file__), "assets", "images", "car_black_top.png")
img.save(out_path, "PNG")
print(f"✅ Saved {out_path} ({img.size[0]}x{img.size[1]})")
