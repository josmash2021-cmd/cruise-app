"""
Generate Cruise app launcher icon: METALLIC GOLD bg + BLACK 'Cruise' text — HD crisp.
Produces BOTH legacy ic_launcher.png AND adaptive icon layers (foreground/background)
so the icon fills the full circle on modern Android.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, textwrap, math, re

# ── Dimensions ──
SIZE     = 1024        # Legacy master
RENDER   = SIZE * 4    # 4x supersampling
# Adaptive icons: foreground is 108dp; safe-zone is inner 72dp (66.67%).
# At xxxhdpi that's 432px foreground, 288px safe zone.
ADAPT_FG  = 432
ADAPT_R   = ADAPT_FG * 4  # render size for supersampling

# ── Colors — Dorado Amarillento (Golden-Yellow) Palette ──
GOLD_DARK    = (180, 140, 20)     # #B48C14 — warm dark gold
GOLD_MID     = (218, 175, 40)     # #DAAF28 — golden yellow
GOLD_LIGHT   = (240, 200, 70)     # #F0C846 — bright golden yellow
GOLD_BRIGHT  = (255, 220, 100)    # #FFDC64 — brightest golden yellow
TEXT_CLR     = (0, 0, 0)          # pure black
STROKE_W     = 4                  # thin stroke for legible, clean letters

TEXT = 'Cruise'

# Use medium-weight fonts (Bold, not Black) for cleaner legibility
FONTS = [
    'C:/Windows/Fonts/arialbd.ttf',    # Arial Bold — clean & legible
    'C:/Windows/Fonts/calibrib.ttf',   # Calibri Bold
    'C:/Windows/Fonts/ariblk.ttf',     # Arial Black — fallback
    'C:/Windows/Fonts/segoeui.ttf',    # Segoe UI
]


def _pick_font(draw, canvas_size, fill_pct=0.52):
    """Find the largest font that fits TEXT within fill_pct of canvas_size."""
    target_w = int(canvas_size * fill_pct)
    for try_size in range(1400, 60, -4):
        for font_path in FONTS:
            if os.path.exists(font_path):
                f = ImageFont.truetype(font_path, try_size)
                bb = draw.textbbox((0, 0), TEXT, font=f, stroke_width=STROKE_W)
                if (bb[2] - bb[0]) <= target_w:
                    return f
    return ImageFont.load_default()


def _draw_metallic_bg(img):
    """Draw a metallic gold gradient background with subtle radial sheen."""
    w, h = img.size
    draw = ImageDraw.Draw(img)

    # Vertical gradient: dark gold top → bright gold center → dark gold bottom
    for y in range(h):
        t = y / max(h - 1, 1)
        # Sinusoidal curve: brightest at center (t=0.5)
        brightness = 0.5 + 0.5 * math.sin(t * math.pi)
        r = int(GOLD_DARK[0] + (GOLD_BRIGHT[0] - GOLD_DARK[0]) * brightness)
        g = int(GOLD_DARK[1] + (GOLD_BRIGHT[1] - GOLD_DARK[1]) * brightness)
        b = int(GOLD_DARK[2] + (GOLD_BRIGHT[2] - GOLD_DARK[2]) * brightness)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    # Overlay a radial highlight at upper-center for metallic sheen
    highlight = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    cx, cy = w // 2, int(h * 0.38)
    radius = int(w * 0.45)
    for rad in range(radius, 0, -1):
        alpha = int(60 * (1 - rad / radius) ** 1.5)
        alpha = min(alpha, 60)
        hd.ellipse([cx - rad, cy - rad, cx + rad, cy + rad],
                   fill=(255, 245, 220, alpha))
    img.paste(Image.alpha_composite(img.convert('RGBA'), highlight).convert('RGB'),
              (0, 0))


def _draw_text(draw, canvas_size, font):
    """Draw centered black text with subtle shadow for depth."""
    bb = draw.textbbox((0, 0), TEXT, font=font, stroke_width=STROKE_W)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    x = (canvas_size - tw) / 2 - bb[0]
    y = (canvas_size - th) / 2 - bb[1]
    # Subtle dark shadow for depth / emboss effect
    draw.text((x + 2, y + 4), TEXT, font=font,
              fill=(80, 65, 25), stroke_width=STROKE_W, stroke_fill=(80, 65, 25))
    # Main black text
    draw.text((x, y), TEXT, font=font,
              fill=TEXT_CLR, stroke_width=STROKE_W, stroke_fill=TEXT_CLR)


# ═══════════════════════════════════════
#  1. LEGACY ICON (ic_launcher.png) — Metallic Gold BG
# ═══════════════════════════════════════
img_hi = Image.new('RGB', (RENDER, RENDER), GOLD_MID)
_draw_metallic_bg(img_hi)
d_hi   = ImageDraw.Draw(img_hi)
font_legacy = _pick_font(d_hi, RENDER, fill_pct=0.72)
_draw_text(d_hi, RENDER, font_legacy)
img_legacy = img_hi.resize((SIZE, SIZE), Image.LANCZOS)

# ═══════════════════════════════════════
#  2. ADAPTIVE FOREGROUND (text on transparent, centered in 108dp canvas)
#     Text fills ~78 % of the safe zone (inner 66.67 %)
# ═══════════════════════════════════════
fg_hi = Image.new('RGBA', (ADAPT_R, ADAPT_R), (0, 0, 0, 0))
d_fg  = ImageDraw.Draw(fg_hi)
font_fg = _pick_font(d_fg, ADAPT_R, fill_pct=0.52)
_draw_text(d_fg, ADAPT_R, font_fg)
fg_master = fg_hi.resize((ADAPT_FG, ADAPT_FG), Image.LANCZOS)

# ═══════════════════════════════════════
#  3. ADAPTIVE BACKGROUND (metallic gold image layer)
# ═══════════════════════════════════════
bg_layer = Image.new('RGB', (ADAPT_R, ADAPT_R), GOLD_MID)
_draw_metallic_bg(bg_layer)
bg_master = bg_layer.resize((ADAPT_FG, ADAPT_FG), Image.LANCZOS)

# ═══════════════════════════════════════
#  OUTPUT PATHS
# ═══════════════════════════════════════
out_dir  = os.path.dirname(os.path.abspath(__file__))
res_base = os.path.join(out_dir, 'android', 'app', 'src', 'main', 'res')

# Save master asset
master_path = os.path.join(out_dir, 'assets', 'images', 'cruise_icon_1024.png')
img_legacy.save(master_path, 'PNG')
print(f'Saved master: {master_path}')

# Mipmap sizes (legacy square icon)
LEGACY_SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, sz in LEGACY_SIZES.items():
    fp = os.path.join(res_base, folder)
    os.makedirs(fp, exist_ok=True)
    img_legacy.resize((sz, sz), Image.LANCZOS).save(os.path.join(fp, 'ic_launcher.png'), 'PNG')
    print(f'  legacy  {folder}/ic_launcher.png  {sz}x{sz}')

# Adaptive foreground sizes
ADAPT_SIZES = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
}
for folder, sz in ADAPT_SIZES.items():
    fp = os.path.join(res_base, folder)
    os.makedirs(fp, exist_ok=True)
    fg_master.resize((sz, sz), Image.LANCZOS).save(os.path.join(fp, 'ic_launcher_foreground.png'), 'PNG')
    print(f'  fg      {folder}/ic_launcher_foreground.png  {sz}x{sz}')

# Adaptive background sizes (metallic gold image layer)
for folder, sz in ADAPT_SIZES.items():
    fp = os.path.join(res_base, folder)
    os.makedirs(fp, exist_ok=True)
    bg_master.resize((sz, sz), Image.LANCZOS).save(os.path.join(fp, 'ic_launcher_background.png'), 'PNG')
    print(f'  bg      {folder}/ic_launcher_background.png  {sz}x{sz}')

# ── Adaptive icon XML (use mipmap background image for metallic gradient) ──
anydpi_dir = os.path.join(res_base, 'mipmap-anydpi-v26')
os.makedirs(anydpi_dir, exist_ok=True)
xml_content = textwrap.dedent("""\
    <?xml version="1.0" encoding="utf-8"?>
    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
        <background android:drawable="@mipmap/ic_launcher_background"/>
        <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    </adaptive-icon>
""")
with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w') as f:
    f.write(xml_content)
print(f'  xml     mipmap-anydpi-v26/ic_launcher.xml')

# ── Update colors.xml fallback bg color to gold ──
values_dir = os.path.join(res_base, 'values')
os.makedirs(values_dir, exist_ok=True)
colors_path = os.path.join(values_dir, 'colors.xml')
gold_hex = '#DAAF28'
bg_entry = f'<color name="ic_launcher_background">{gold_hex}</color>'
if os.path.exists(colors_path):
    with open(colors_path, 'r') as f:
        content = f.read()
    if 'ic_launcher_background' in content:
        content = re.sub(
            r'<color name="ic_launcher_background">[^<]*</color>',
            bg_entry, content)
    else:
        content = content.replace('</resources>', f'    {bg_entry}\n</resources>')
    with open(colors_path, 'w') as f:
        f.write(content)
else:
    with open(colors_path, 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                f'    {bg_entry}\n</resources>\n')
# Remove standalone file if it exists (avoid duplicate resource)
standalone = os.path.join(values_dir, 'ic_launcher_background.xml')
if os.path.exists(standalone):
    os.remove(standalone)
print(f'  color   values/colors.xml (ic_launcher_background -> {gold_hex})')

# ── Web icons ──
web_dir = os.path.join(out_dir, 'web', 'icons')
os.makedirs(web_dir, exist_ok=True)
for name, wsz in [('Icon-192.png', 192), ('Icon-512.png', 512),
                   ('Icon-maskable-192.png', 192), ('Icon-maskable-512.png', 512)]:
    img_legacy.resize((wsz, wsz), Image.LANCZOS).save(os.path.join(web_dir, name), 'PNG')
    print(f'  web     {name}  {wsz}x{wsz}')

favicon = img_legacy.resize((32, 32), Image.LANCZOS)
favicon.save(os.path.join(out_dir, 'web', 'favicon.png'), 'PNG')
print('  web     favicon.png  32x32')

print('\nDone — METALLIC GOLD bg, BLACK text, adaptive + legacy, HD.')
