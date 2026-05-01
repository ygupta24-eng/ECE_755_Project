import numpy as np
import re
from PIL import Image

# ============================================================
# IMAGE SIZE (x: 0..507, y: 0..507)
# ============================================================
H = 508   # rows = x
W = 508   # cols = y

# Allocate 4 channels
ch0 = np.zeros((H, W), dtype=np.int32)
ch1 = np.zeros((H, W), dtype=np.int32)
ch2 = np.zeros((H, W), dtype=np.int32)
ch3 = np.zeros((H, W), dtype=np.int32)

# Regex to extract (x,y): p0 p1 p2 p3
pattern = re.compile(
    r"\((\d+),(\d+)\):\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)"
)

# ============================================================
# PARSE PSUM FILE
# ============================================================
with open("psum_results_girl.txt", "r") as f:
    for line in f:
        matches = pattern.findall(line)
        if not matches:
            continue

        for (x, y, p0, p1, p2, p3) in matches:
            x = int(x)
            y = int(y)

            if x < H and y < W:
                ch0[x, y] = int(p0)
                ch1[x, y] = int(p1)
                ch2[x, y] = int(p2)
                ch3[x, y] = int(p3)

# ============================================================
# IMPROVED NORMALIZATION
# ============================================================
def normalize_signed(arr):
    max_abs = np.max(np.abs(arr))
    if max_abs == 0:
        return np.full_like(arr, 128, dtype=np.uint8)

    arr_norm = (arr / max_abs) * 127 + 128
    return np.clip(arr_norm, 0, 255).astype(np.uint8)

img0 = normalize_signed(ch0)
img1 = normalize_signed(ch1)
img2 = normalize_signed(ch2)
img3 = normalize_signed(ch3)

# ============================================================
# SAVE IMAGES
# ============================================================
Image.fromarray(img0).save("channel0_vertical_edges.png")
Image.fromarray(img1).save("channel1_horizontal_edges.png")
Image.fromarray(img2).save("channel2_diag45_edges.png")
Image.fromarray(img3).save("channel3_diag135_edges.png")

print("Saved all 4 channel images (correct size, correct mapping, improved normalization).")

