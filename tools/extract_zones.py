"""
Extract body map zone polygons from clinical PNG using OpenCV flood-fill.

Usage:  python extract_zones.py
Output: prints Dart code for kBackRegions to stdout
        saves debug overlay images to tools/debug/
"""
import cv2
import numpy as np
import os

IMG_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'body_map_clinical.png')
DEBUG_DIR = os.path.join(os.path.dirname(__file__), 'debug')

# ── Seed points: one (x, y) per zone, guaranteed inside the zone ──────────
# Front zones: derived from working polygon centroids in easi_models.dart
# Back zones: estimated from visible zone-number positions in the image
ZONE_SEEDS = {
    # ── FRONT BODY ──────────────────────────────────────────────────
    'z1':  (335, 75),    # R. Scalp
    'z2':  (385, 75),    # L. Scalp
    'z3':  (360, 170),   # Neck
    'z4':  (310, 245),   # R. Chest
    'z5':  (425, 245),   # L. Chest
    'z6':  (195, 310),   # R. Upper Arm
    'z7':  (530, 310),   # L. Upper Arm
    'z8':  (125, 440),   # R. Forearm
    'z9':  (610, 430),   # L. Forearm
    'z10': (88, 545),    # R. Hand
    'z11': (660, 545),   # L. Hand
    'z12': (315, 345),   # R. Upper Abd
    'z13': (420, 345),   # L. Upper Abd
    'z14': (320, 450),   # R. Lower Abd
    'z15': (410, 440),   # L. Lower Abd
    'z16': (360, 540),   # Groin
    'z17': (310, 650),   # R. Thigh
    'z18': (425, 650),   # L. Thigh
    'z49': (325, 790),   # R. Knee
    'z50': (420, 790),   # L. Knee
    'z19': (325, 920),   # R. Shin
    'z20': (415, 920),   # L. Shin
    'z21': (295, 1060),  # R. Foot
    'z22': (440, 1060),  # L. Foot

    # ── BACK BODY ───────────────────────────────────────────────────
    'z23': (1135, 75),   # R. Scalp (B)
    'z24': (1175, 75),   # L. Scalp (B)
    'z25': (1155, 170),  # Nape
    'z26': (1100, 240),  # L. Upper Back
    'z27': (1210, 240),  # R. Upper Back
    'z28': (990, 300),   # L. Upper Arm (B)
    'z29': (1320, 300),  # R. Upper Arm (B)
    'z30': (920, 430),   # L. Forearm (B)
    'z31': (1390, 430),  # R. Forearm (B)
    'z32': (870, 550),   # L. Hand (B)
    'z33': (1440, 550),  # R. Hand (B)
    'z34': (1100, 330),  # L. Mid Back
    'z35': (1210, 330),  # R. Mid Back
    'z36': (1100, 415),  # L. Lower Back
    'z37': (1210, 415),  # R. Lower Back
    'z46': (1155, 475),  # Sacrum
    'z38': (1095, 530),  # L. Buttock
    'z39': (1215, 530),  # R. Buttock
    'z40': (1090, 680),  # L. Thigh (B)
    'z41': (1220, 680),  # R. Thigh (B)
    'z47': (1055, 860),  # L. Back Knee
    'z48': (1245, 860),  # R. Back Knee
    'z42': (1045, 960),  # L. Calf
    'z43': (1245, 960),  # R. Calf
    'z44': (1030, 1065), # L. Foot (B)
    'z45': (1250, 1065), # R. Foot (B)
}

# Zone metadata
ZONE_META = {
    'z1':  ('R. Scalp',         True,  'headNeck'),
    'z2':  ('L. Scalp',         True,  'headNeck'),
    'z3':  ('Neck',             True,  'headNeck'),
    'z4':  ('R. Chest',         True,  'trunk'),
    'z5':  ('L. Chest',         True,  'trunk'),
    'z6':  ('R. Upper Arm',     True,  'upperExt'),
    'z7':  ('L. Upper Arm',     True,  'upperExt'),
    'z8':  ('R. Forearm',       True,  'upperExt'),
    'z9':  ('L. Forearm',       True,  'upperExt'),
    'z10': ('R. Hand',          True,  'upperExt'),
    'z11': ('L. Hand',          True,  'upperExt'),
    'z12': ('R. Upper Abd.',    True,  'trunk'),
    'z13': ('L. Upper Abd.',    True,  'trunk'),
    'z14': ('R. Lower Abd.',    True,  'trunk'),
    'z15': ('L. Lower Abd.',    True,  'trunk'),
    'z16': ('Groin',            True,  'trunk'),
    'z17': ('R. Thigh',         True,  'lowerExt'),
    'z18': ('L. Thigh',         True,  'lowerExt'),
    'z49': ('R. Knee',          True,  'lowerExt'),
    'z50': ('L. Knee',          True,  'lowerExt'),
    'z19': ('R. Shin',          True,  'lowerExt'),
    'z20': ('L. Shin',          True,  'lowerExt'),
    'z21': ('R. Foot',          True,  'lowerExt'),
    'z22': ('L. Foot',          True,  'lowerExt'),
    'z23': ('R. Scalp (B)',     False, 'headNeck'),
    'z24': ('L. Scalp (B)',     False, 'headNeck'),
    'z25': ('Nape',             False, 'headNeck'),
    'z26': ('L. Upper Back',    False, 'trunk'),
    'z27': ('R. Upper Back',    False, 'trunk'),
    'z28': ('L. Upper Arm (B)', False, 'upperExt'),
    'z29': ('R. Upper Arm (B)', False, 'upperExt'),
    'z30': ('L. Forearm (B)',   False, 'upperExt'),
    'z31': ('R. Forearm (B)',   False, 'upperExt'),
    'z32': ('L. Hand (B)',      False, 'upperExt'),
    'z33': ('R. Hand (B)',      False, 'upperExt'),
    'z34': ('L. Mid Back',      False, 'trunk'),
    'z35': ('R. Mid Back',      False, 'trunk'),
    'z36': ('L. Lower Back',    False, 'trunk'),
    'z37': ('R. Lower Back',    False, 'trunk'),
    'z46': ('Sacrum',           False, 'trunk'),
    'z38': ('L. Buttock',       False, 'trunk'),
    'z39': ('R. Buttock',       False, 'trunk'),
    'z40': ('L. Thigh (B)',     False, 'lowerExt'),
    'z41': ('R. Thigh (B)',     False, 'lowerExt'),
    'z47': ('L. Back Knee',     False, 'lowerExt'),
    'z48': ('R. Back Knee',     False, 'lowerExt'),
    'z42': ('L. Calf',          False, 'lowerExt'),
    'z43': ('R. Calf',          False, 'lowerExt'),
    'z44': ('L. Foot (B)',      False, 'lowerExt'),
    'z45': ('R. Foot (B)',      False, 'lowerExt'),
}

# Maximum expected area for any single zone (to detect flood-fill leaks)
MAX_ZONE_AREA = 80000  # pixels


def preprocess(img):
    """Convert to binary boundary mask: 255 = boundary line, 0 = zone interior."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Threshold: dark pixels (< 160) are boundaries — generous threshold to capture thin lines
    _, binary = cv2.threshold(gray, 160, 255, cv2.THRESH_BINARY_INV)

    # Remove small blobs (digit text, noise) that could break zone interiors
    n_labels, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    cleaned = binary.copy()
    for i in range(1, n_labels):
        area = stats[i, cv2.CC_STAT_AREA]
        w = stats[i, cv2.CC_STAT_WIDTH]
        h = stats[i, cv2.CC_STAT_HEIGHT]
        aspect = max(w, h) / (min(w, h) + 1)
        # Remove only compact small blobs (text/digits) — keep elongated lines
        if area < 400 and aspect < 4:
            cleaned[labels == i] = 0

    # Morphological closing to bridge small gaps (close then re-thin)
    kernel = np.ones((5, 5), np.uint8)
    closed = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, kernel)

    # Dilate slightly for safety
    kernel2 = np.ones((3, 3), np.uint8)
    dilated = cv2.dilate(closed, kernel2, iterations=1)

    # ── Manual boundary repairs (known broken lines) ──────────────
    # Front body:
    cv2.line(dilated, (272, 192), (448, 192), 255, 3)   # neck-to-chest
    cv2.line(dilated, (270, 290), (460, 290), 255, 3)    # chest-to-abdomen
    # Front hand outlines (close finger gaps):
    cv2.line(dilated, (60, 570), (120, 530), 255, 3)     # R. hand outline
    cv2.line(dilated, (630, 530), (688, 570), 255, 3)    # L. hand outline

    # Back body horizontal dividers:
    cv2.line(dilated, (1060, 192), (1250, 192), 255, 3)  # nape-to-upper-back
    cv2.line(dilated, (1065, 275), (1245, 275), 255, 3)  # upper-back-to-mid-back
    cv2.line(dilated, (1080, 370), (1230, 370), 255, 3)  # mid-back-to-lower-back
    cv2.line(dilated, (1085, 450), (1225, 450), 255, 3)  # lower-back-to-sacrum

    # Back body left arm (z28/z30 boundary repairs):
    cv2.line(dilated, (1045, 200), (1050, 275), 255, 3)  # left shoulder-to-armpit inner edge
    cv2.line(dilated, (945, 365), (1010, 365), 255, 3)   # elbow line (z28/z30 boundary)
    cv2.line(dilated, (870, 500), (910, 500), 255, 3)    # wrist line (z30/z32 boundary)

    # Back body right arm:
    cv2.line(dilated, (1260, 200), (1255, 275), 255, 3)  # right shoulder-to-armpit inner edge
    cv2.line(dilated, (1300, 365), (1365, 365), 255, 3)  # R elbow line
    cv2.line(dilated, (1400, 500), (1440, 500), 255, 3)  # R wrist line

    # Back scalp midline:
    cv2.line(dilated, (1155, 20), (1155, 140), 255, 3)   # scalp midline

    # Back body left side vertical body edge repairs (thin inner thigh/leg):
    cv2.line(dilated, (1040, 560), (1050, 590), 255, 3)  # buttock-to-thigh L
    cv2.line(dilated, (1055, 810), (1060, 815), 255, 3)  # thigh-to-knee L
    cv2.line(dilated, (1040, 910), (1050, 920), 255, 3)  # knee-to-calf L
    cv2.line(dilated, (1015, 1025), (1045, 1030), 255, 3)# calf-to-foot L

    # Back left thigh inner edge (between z40 and z41):
    cv2.line(dilated, (1155, 580), (1155, 810), 255, 3)  # midline between thighs

    # Back knee horizontal lines:
    cv2.line(dilated, (1030, 810), (1085, 810), 255, 3)  # L knee top
    cv2.line(dilated, (1025, 920), (1085, 920), 255, 3)  # L knee bottom
    cv2.line(dilated, (1225, 810), (1280, 810), 255, 3)  # R knee top
    cv2.line(dilated, (1220, 920), (1270, 920), 255, 3)  # R knee bottom

    # Back calf-to-foot boundary:
    cv2.line(dilated, (1010, 1030), (1070, 1030), 255, 3)  # L foot top
    cv2.line(dilated, (1220, 1030), (1270, 1030), 255, 3)  # R foot top

    # Back lower back left boundary (z36 leaks):
    cv2.line(dilated, (1085, 370), (1085, 452), 255, 3)  # left edge of lower back

    # Back hand finger closures:
    cv2.line(dilated, (855, 530), (895, 510), 255, 3)    # L hand fingers close
    cv2.line(dilated, (1415, 510), (1455, 530), 255, 3)  # R hand fingers close

    return dilated


def extract_zone(boundary_mask, seed, zone_id):
    """Flood-fill from seed point, extract simplified contour polygon."""
    h, w = boundary_mask.shape[:2]
    sx, sy = seed

    # Check seed is inside bounds and on a white (non-boundary) pixel
    if sx < 0 or sx >= w or sy < 0 or sy >= h:
        print(f"  WARNING: {zone_id} seed ({sx},{sy}) out of bounds!")
        return None
    if boundary_mask[sy, sx] == 255:
        # Seed is on a boundary line — try to nudge it
        for dx in range(-5, 6):
            for dy in range(-5, 6):
                nx, ny = sx + dx, sy + dy
                if 0 <= nx < w and 0 <= ny < h and boundary_mask[ny, nx] == 0:
                    sx, sy = nx, ny
                    break
            else:
                continue
            break
        else:
            print(f"  WARNING: {zone_id} seed ({seed[0]},{seed[1]}) stuck on boundary!")
            return None

    # Flood-fill on inverted mask (fill the white interior)
    fill_mask = np.zeros((h + 2, w + 2), np.uint8)
    work = boundary_mask.copy()
    # Invert so boundaries are 255, interiors are 0
    # floodFill fills connected 0-pixels starting from seed
    _, work, fill_mask, _ = cv2.floodFill(work, fill_mask, (sx, sy), 128)

    # Extract the filled region
    zone_mask = np.zeros((h, w), np.uint8)
    zone_mask[work == 128] = 255

    # Check area
    area = cv2.countNonZero(zone_mask)
    if area > MAX_ZONE_AREA:
        print(f"  WARNING: {zone_id} area={area} exceeds max ({MAX_ZONE_AREA}) — flood-fill leaked!")
        return None
    if area < 50:
        print(f"  WARNING: {zone_id} area={area} too small — bad seed?")
        return None

    # Find contour
    contours, _ = cv2.findContours(zone_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        print(f"  WARNING: {zone_id} no contour found!")
        return None

    # Take the largest contour
    contour = max(contours, key=cv2.contourArea)

    # Simplify: epsilon = 0.8% of perimeter for smooth but accurate curves
    epsilon = 0.008 * cv2.arcLength(contour, True)
    approx = cv2.approxPolyDP(contour, epsilon, True)

    # Extract points
    points = [(int(p[0][0]), int(p[0][1])) for p in approx]
    return points, area, zone_mask


def generate_dart(zones_data, front_or_back):
    """Generate Dart code for a list of zones."""
    group_map = {'headNeck': 'EasiGroup.headNeck', 'upperExt': 'EasiGroup.upperExt',
                 'trunk': 'EasiGroup.trunk', 'lowerExt': 'EasiGroup.lowerExt'}

    lines = []
    for zid, points in sorted(zones_data.items(), key=lambda x: int(x[0][1:])):
        label, is_front, group = ZONE_META[zid]
        num = int(zid[1:])
        if (front_or_back == 'front') != is_front:
            continue

        lines.append(f"  // {zid} -- {label}")
        lines.append(f"  BodyRegion(")
        lines.append(f"    id: '{zid}', label: '{label}', number: {num}, isFront: {'true' if is_front else 'false'},")
        lines.append(f"    group: {group_map[group]},")
        lines.append(f"    polyPoints: [")
        for i, (px, py) in enumerate(points):
            comma = ',' if i < len(points) - 1 else ','
            lines.append(f"      Offset({px}, {py}){comma}")
        lines.append(f"    ],")
        lines.append(f"  ),\n")

    return '\n'.join(lines)


def main():
    os.makedirs(DEBUG_DIR, exist_ok=True)

    print(f"Loading image: {IMG_PATH}")
    img = cv2.imread(IMG_PATH)
    if img is None:
        print("ERROR: Could not load image!")
        return
    h, w = img.shape[:2]
    print(f"Image size: {w}x{h}")

    print("Preprocessing (threshold, clean text, dilate, repair gaps)...")
    boundary = preprocess(img)
    cv2.imwrite(os.path.join(DEBUG_DIR, 'boundary.png'), boundary)

    # Extract all zones
    front_zones = {}
    back_zones = {}
    debug_overlay = img.copy()
    colors = {}

    print("\nExtracting zones...")
    for zid, seed in ZONE_SEEDS.items():
        result = extract_zone(boundary, seed, zid)
        if result is None:
            continue
        points, area, zone_mask = result
        is_front = ZONE_META[zid][1]

        if is_front:
            front_zones[zid] = points
        else:
            back_zones[zid] = points

        # Draw on debug overlay
        np_pts = np.array(points, dtype=np.int32).reshape((-1, 1, 2))
        color = tuple(int(c) for c in np.random.randint(60, 255, 3))
        colors[zid] = color
        cv2.drawContours(debug_overlay, [np_pts], -1, color, 2)
        # Draw zone label at centroid
        cx = sum(p[0] for p in points) // len(points)
        cy = sum(p[1] for p in points) // len(points)
        cv2.putText(debug_overlay, zid, (cx - 10, cy + 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.35, color, 1)

        print(f"  {zid}: {len(points)} points, area={area}")

    cv2.imwrite(os.path.join(DEBUG_DIR, 'overlay_all.png'), debug_overlay)

    # Save back-only overlay for focused inspection
    back_overlay = img.copy()
    for zid, points in back_zones.items():
        np_pts = np.array(points, dtype=np.int32).reshape((-1, 1, 2))
        color = colors.get(zid, (0, 255, 0))
        cv2.drawContours(back_overlay, [np_pts], -1, color, 2)
        cx = sum(p[0] for p in points) // len(points)
        cy = sum(p[1] for p in points) // len(points)
        cv2.putText(back_overlay, zid, (cx - 10, cy + 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.35, color, 1)
    cv2.imwrite(os.path.join(DEBUG_DIR, 'overlay_back.png'), back_overlay)

    # ── Mirror missing left-side back zones from right-side ──────────
    # Back body is symmetric around x=1155.
    # If a left zone leaked but its right mirror extracted, mirror it.
    MIRROR_PAIRS = {
        # left_zone: right_zone
        'z23': 'z24',  # R. Scalp ← L. Scalp
        'z28': 'z29',  # L. Upper Arm ← R. Upper Arm
        'z30': 'z31',  # L. Forearm ← R. Forearm
        'z33': 'z32',  # R. Hand ← L. Hand (note: z32 is left, z33 is right)
        'z36': 'z37',  # L. Lower Back ← R. Lower Back
        'z40': 'z41',  # L. Thigh ← R. Thigh
        'z47': 'z48',  # L. Back Knee ← R. Back Knee
        'z42': 'z43',  # L. Calf ← R. Calf
        'z44': 'z45',  # L. Foot ← R. Foot
    }
    MIDLINE = 1155  # back body midline x-coordinate

    for missing_id, source_id in MIRROR_PAIRS.items():
        if missing_id not in back_zones and source_id in back_zones:
            source_pts = back_zones[source_id]
            # Mirror: new_x = 2 * MIDLINE - old_x, keep y the same
            # Reverse point order to maintain winding direction
            mirrored = [(2 * MIDLINE - x, y) for x, y in source_pts]
            mirrored.reverse()
            back_zones[missing_id] = mirrored
            print(f"  {missing_id}: MIRRORED from {source_id} ({len(mirrored)} points)")

    # Fix z46/z38 merge — if they got the same polygon, separate them
    # z46 (Sacrum) should be the small diamond at the center
    # z38 (L. Buttock) is the larger area to the left
    if 'z46' in back_zones and 'z38' in back_zones:
        pts46 = back_zones['z46']
        pts38 = back_zones['z38']
        if pts46 == pts38:
            print("  z46/z38 merged — re-extracting z46 with tighter seed...")
            # Try re-extracting z46 at the exact center of sacrum
            result = extract_zone(boundary, (1155, 480), 'z46')
            if result and result[1] < 5000:
                back_zones['z46'] = result[0]
                print(f"  z46: re-extracted {len(result[0])} points, area={result[1]}")

    # ── Generate Dart code ────────────────────────────────────────────
    print("\n-- FRONT ZONES DART CODE --")
    front_dart = generate_dart(front_zones, 'front')
    print(front_dart)

    print("\n-- BACK ZONES DART CODE --")
    back_dart = generate_dart(back_zones, 'back')
    print(back_dart)

    # Save to files
    with open(os.path.join(DEBUG_DIR, 'front_zones.dart'), 'w') as f:
        f.write(f"const kFrontRegions = <BodyRegion>[\n\n{front_dart}\n];\n")
    with open(os.path.join(DEBUG_DIR, 'back_zones.dart'), 'w') as f:
        f.write(f"const kBackRegions = <BodyRegion>[\n\n{back_dart}\n];\n")

    print(f"\nDone! {len(front_zones)} front + {len(back_zones)} back zones extracted.")
    print(f"Debug images saved to: {DEBUG_DIR}/")
    print(f"Dart code saved to: {DEBUG_DIR}/front_zones.dart, {DEBUG_DIR}/back_zones.dart")


if __name__ == '__main__':
    main()
