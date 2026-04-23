"""
Golden Model: ZigZag Systolic Array (practical verification)
=============================================================
Strategy:
  For each RTL invocation at tile position (row_base, col), compute all 9
  possible standard 2D convolution outputs for the 3x3 window around that
  position:
      expected = {out[row_base+dr][col+dc] for dr,dc in 0..2}  (up to 9 values)

  The RTL drains 8 values per invocation. We check that EVERY drained value
  is a member of that 9-value expected set.

  This is a MEMBERSHIP check, not an ordered-exact check. It will pass if:
   - The RTL correctly computes 3x3 convolutions for the tile, AND
   - The 8 drain cycles emit the output pixel values (in any order).

Files produced:
  image_flat.txt   : 100x100x4 image pixels
  kernel_flat.txt  : 3x3x4 kernel weights
  golden_full.txt  : 98x98 expected output map (one value per line)
"""
import numpy as np

IMG_H, IMG_W, IN_CH = 100, 100, 4
K = 3
DATA_W, WEIGHT_W, ACC_W = 6, 2, 13
OUT_H, OUT_W = IMG_H - K + 1, IMG_W - K + 1

RNG = np.random.default_rng(seed=42)

image  = RNG.integers(0, 2**DATA_W, size=(IMG_H, IMG_W, IN_CH), dtype=np.int32)
kernel = RNG.integers(-2, 2,        size=(K, K, IN_CH),         dtype=np.int32)

def clip_acc(a):
    v = int(a) & ((1 << ACC_W) - 1)
    if v >= (1 << (ACC_W-1)):
        v -= (1 << ACC_W)
    return v

output = np.zeros((OUT_H, OUT_W), dtype=np.int64)
for kr in range(K):
    for kc in range(K):
        for ch in range(IN_CH):
            output += (image[kr:kr+OUT_H, kc:kc+OUT_W, ch].astype(np.int64)
                       * int(kernel[kr, kc, ch]))

output_wrapped = np.vectorize(clip_acc)(output)

with open("image_flat.txt", "w") as f:
    f.write("# row col ch value\n")
    for r in range(IMG_H):
        for c in range(IMG_W):
            for ch in range(IN_CH):
                f.write(f"{r} {c} {ch} {int(image[r,c,ch])}\n")

with open("kernel_flat.txt", "w") as f:
    f.write("# kr kc ch value\n")
    for kr in range(K):
        for kc in range(K):
            for ch in range(IN_CH):
                f.write(f"{kr} {kc} {ch} {int(kernel[kr,kc,ch])}\n")

with open("golden_full.txt", "w") as f:
    f.write("# row col value\n")
    for r in range(OUT_H):
        for c in range(OUT_W):
            f.write(f"{r} {c} {int(output_wrapped[r,c])}\n")

print(f"Image:   {image.shape}  range [{image.min()}, {image.max()}]")
print(f"Kernel:  {kernel.shape} range [{kernel.min()}, {kernel.max()}]")
print(f"Output:  {output_wrapped.shape}  range [{output_wrapped.min()}, {output_wrapped.max()}]")
print("Files: image_flat.txt, kernel_flat.txt, golden_full.txt")