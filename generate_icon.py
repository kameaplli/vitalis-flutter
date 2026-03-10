"""Generate Vitalis app icon PNGs at all required sizes.
Run: python generate_icon.py
Requires: pip install Pillow
"""
from PIL import Image, ImageDraw, ImageFont
import math
import os

def create_icon(size=1024):
    """Create a high-quality Vitalis app icon."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background with rounded corners
    radius = int(size * 0.22)  # ~22% corner radius (iOS-style)

    # Draw rounded rectangle background
    # Deep emerald gradient effect (simulated with solid + overlay)
    bg_color = (18, 110, 88)  # Deep emerald
    _rounded_rect(draw, 0, 0, size, size, radius, bg_color)

    # Subtle lighter inner area
    margin = int(size * 0.04)
    inner_color = (22, 120, 95)
    _rounded_rect(draw, margin, margin, size - margin, size - margin,
                  radius - margin, inner_color)

    # Draw the "V" letterform
    cx, cy = size // 2, size // 2
    v_top = int(size * 0.18)
    v_bottom = int(size * 0.62)
    v_width = int(size * 0.34)
    stroke = int(size * 0.055)

    # V shape points
    v_left_top = (cx - v_width, v_top)
    v_bottom_pt = (cx, v_bottom)
    v_right_top = (cx + v_width, v_top)

    # Draw V with thick white lines
    white = (255, 255, 255)
    draw.line([v_left_top, v_bottom_pt], fill=white, width=stroke)
    draw.line([v_bottom_pt, v_right_top], fill=white, width=stroke)

    # Round the endpoints
    for pt in [v_left_top, v_bottom_pt, v_right_top]:
        r = stroke // 2
        draw.ellipse([pt[0]-r, pt[1]-r, pt[0]+r, pt[1]+r], fill=white)

    # Small leaf accent at top-right of V
    leaf_x, leaf_y = v_right_top
    leaf_size = int(size * 0.06)
    leaf_color = (74, 222, 128)  # Bright green
    draw.ellipse([
        leaf_x - leaf_size//4, leaf_y - leaf_size,
        leaf_x + leaf_size, leaf_y + leaf_size//4
    ], fill=leaf_color)

    # Heartbeat / pulse line below the V
    pulse_y = int(size * 0.72)
    pulse_left = int(size * 0.15)
    pulse_right = int(size * 0.85)
    pulse_stroke = int(size * 0.022)
    pulse_height = int(size * 0.08)

    pulse_color = (255, 255, 255, 200)
    # Create pulse overlay for alpha support
    overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)

    # Pulse line: flat - up - down - up - flat
    seg = (pulse_right - pulse_left) / 10
    points = [
        (pulse_left, pulse_y),
        (pulse_left + seg * 2, pulse_y),
        (pulse_left + seg * 3, pulse_y - pulse_height),
        (pulse_left + seg * 4, pulse_y + pulse_height),
        (pulse_left + seg * 5, pulse_y - pulse_height * 1.5),
        (pulse_left + seg * 6, pulse_y + pulse_height * 1.2),
        (pulse_left + seg * 7, pulse_y - pulse_height * 0.6),
        (pulse_left + seg * 8, pulse_y),
        (pulse_right, pulse_y),
    ]
    points = [(int(x), int(y)) for x, y in points]
    odraw.line(points, fill=pulse_color, width=pulse_stroke, joint='curve')

    # Round endpoints of pulse
    for pt in [points[0], points[-1]]:
        r = pulse_stroke // 2
        odraw.ellipse([pt[0]-r, pt[1]-r, pt[0]+r, pt[1]+r], fill=pulse_color)

    img = Image.alpha_composite(img, overlay)

    # Subtle circle ring
    ring_overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(ring_overlay)
    ring_r = int(size * 0.39)
    ring_stroke = max(2, int(size * 0.005))
    ring_color = (255, 255, 255, 35)
    rdraw.ellipse([
        cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r
    ], outline=ring_color, width=ring_stroke)
    img = Image.alpha_composite(img, ring_overlay)

    return img


def _rounded_rect(draw, x1, y1, x2, y2, radius, color):
    """Draw a rounded rectangle."""
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=color)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=color)
    draw.pieslice([x1, y1, x1 + 2*radius, y1 + 2*radius], 180, 270, fill=color)
    draw.pieslice([x2 - 2*radius, y1, x2, y1 + 2*radius], 270, 360, fill=color)
    draw.pieslice([x1, y2 - 2*radius, x1 + 2*radius, y2], 90, 180, fill=color)
    draw.pieslice([x2 - 2*radius, y2 - 2*radius, x2, y2], 0, 90, fill=color)


def main():
    print("Generating Vitalis app icon...")
    icon = create_icon(1024)

    # Save the master 1024px icon
    icon_path = os.path.join(os.path.dirname(__file__), 'assets', 'app_icon.png')
    icon.save(icon_path, 'PNG')
    print(f"  Saved: {icon_path}")

    # Generate Android mipmap sizes
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    res_dir = os.path.join(os.path.dirname(__file__),
                           'android', 'app', 'src', 'main', 'res')

    for folder, px in android_sizes.items():
        out_dir = os.path.join(res_dir, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = icon.resize((px, px), Image.LANCZOS)
        out_path = os.path.join(out_dir, 'ic_launcher.png')
        resized.save(out_path, 'PNG')
        print(f"  Saved: {out_path} ({px}x{px})")

    # Web icons
    web_dir = os.path.join(os.path.dirname(__file__), 'web')
    for px in [192, 512]:
        resized = icon.resize((px, px), Image.LANCZOS)
        out_path = os.path.join(web_dir, 'icons', f'Icon-{px}.png')
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        resized.save(out_path, 'PNG')
        print(f"  Saved: {out_path} ({px}x{px})")

    # Web favicon
    favicon = icon.resize((32, 32), Image.LANCZOS)
    favicon_path = os.path.join(web_dir, 'favicon.png')
    favicon.save(favicon_path, 'PNG')
    print(f"  Saved: {favicon_path} (32x32)")

    print("\nDone! App icons generated successfully.")


if __name__ == '__main__':
    main()
