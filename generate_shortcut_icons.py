"""Generate PNG shortcut icons for Android quick actions.

Vector drawables don't work for shortcut icons — Android's system shortcut
manager runs outside the app context and can't render VectorDrawables.
This script generates simple PNG icons at all required densities.

Usage: python generate_shortcut_icons.py
"""

from PIL import Image, ImageDraw
import os

BASE = os.path.join(os.path.dirname(__file__), "android", "app", "src", "main", "res")

# Android density -> icon size in px (48dp base)
DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

def draw_meal_icon(draw, size):
    """Fork and knife icon."""
    s = size / 24.0  # scale factor from 24dp viewport
    # Fork (left)
    fork_x = 7 * s
    draw.rectangle([fork_x - 1*s, 2*s, fork_x + 1*s, 11*s], fill="#009688")
    draw.rectangle([fork_x - 0.5*s, 12*s, fork_x + 0.5*s, 21*s], fill="#009688")
    # Fork tines
    for dx in [-2, 0, 2]:
        x = fork_x + dx * s
        draw.rectangle([x - 0.4*s, 2*s, x + 0.4*s, 8*s], fill="#009688")
    # Knife (right)
    knife_x = 17 * s
    draw.rounded_rectangle([knife_x - 1.5*s, 2*s, knife_x + 1.5*s, 10*s],
                           radius=1.5*s, fill="#009688")
    draw.rectangle([knife_x - 0.5*s, 10*s, knife_x + 0.5*s, 21*s], fill="#009688")

def draw_hydration_icon(draw, size):
    """Water droplet icon."""
    s = size / 24.0
    cx, cy = 12 * s, 14 * s
    r = 5 * s
    # Teardrop: circle at bottom + triangle at top
    draw.ellipse([cx - r, cy - r + 1*s, cx + r, cy + r + 1*s], fill="#2196F3")
    draw.polygon([
        (cx, 4 * s),
        (cx - r, cy),
        (cx + r, cy),
    ], fill="#2196F3")

def draw_workout_icon(draw, size):
    """Running person icon."""
    s = size / 24.0
    # Head
    cx = 14 * s
    draw.ellipse([cx - 1.5*s, 2*s, cx + 1.5*s, 5*s], fill="#FF5722")
    # Body
    draw.line([(cx, 5*s), (cx - 1*s, 12*s)], fill="#FF5722", width=max(int(1.5*s), 2))
    # Arms
    draw.line([(cx - 4*s, 7*s), (cx + 3*s, 9*s)], fill="#FF5722", width=max(int(1.5*s), 2))
    # Legs
    draw.line([(cx - 1*s, 12*s), (cx - 4*s, 19*s)], fill="#FF5722", width=max(int(1.5*s), 2))
    draw.line([(cx - 1*s, 12*s), (cx + 3*s, 18*s)], fill="#FF5722", width=max(int(1.5*s), 2))

icons = {
    "ic_shortcut_meal": draw_meal_icon,
    "ic_shortcut_hydration": draw_hydration_icon,
    "ic_shortcut_workout": draw_workout_icon,
}

for density, px in DENSITIES.items():
    folder = os.path.join(BASE, density)
    os.makedirs(folder, exist_ok=True)
    for name, draw_fn in icons.items():
        img = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw_fn(draw, px)
        path = os.path.join(folder, f"{name}.png")
        img.save(path, "PNG")
        print(f"  {path}")

print("\nDone! Generated shortcut icon PNGs at all densities.")
