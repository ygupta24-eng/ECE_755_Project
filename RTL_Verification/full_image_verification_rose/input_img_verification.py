import numpy as np
from PIL import Image

INPUT_FILE = "rose_square_6bit_4ch.txt"
WIDTH = 512
HEIGHT = 512
CHANNELS = 4  # R, G, B, Intensity

# -----------------------------
# Step 1: Read & clean data
# -----------------------------
tokens = []
with open(INPUT_FILE, "r") as f:
    for line in f:
        if "//" in line:
            line = line.split("//")[0]
        tokens.extend(line.split())

# -----------------------------
# Step 2: Filter valid hex
# -----------------------------
def is_valid_hex(x):
    try:
        val = int(x, 16)
        return 0 <= val <= 0x3F
    except:
        return False

data = np.array([int(x, 16) for x in tokens if is_valid_hex(x)], dtype=np.uint8)

# -----------------------------
# Step 3: Fix size
# -----------------------------
expected = WIDTH * HEIGHT * CHANNELS

if len(data) < expected:
    raise ValueError(f"Not enough data! Got {len(data)}, expected {expected}")

if len(data) > expected:
    print("Warning: extra data detected, trimming...")
    data = data[:expected]

# -----------------------------
# Step 4: Reshape
# -----------------------------
img = data.reshape((HEIGHT, WIDTH, CHANNELS))

# -----------------------------
# Step 5: Convert 6-bit → 8-bit
# -----------------------------
img_8bit = (img.astype(np.float32) / 63.0 * 255.0).astype(np.uint8)

# -----------------------------
# Step 6: Use only RGB
# -----------------------------
rgb = img_8bit[:, :, :3]

# -----------------------------
# Step 7: Save ONE image
# -----------------------------
image = Image.fromarray(rgb, mode="RGB")
image.save("output.png")

print("Saved: output.png")
