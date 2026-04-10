# golden_reference.py — matches hardware behavior exactly
import numpy as np

IMG_SIZE = 100
OUT_SIZE = 98
IN_CHAN  = 4
np.random.seed(42)

image  = np.random.randint(0, 64, size=(IMG_SIZE, IMG_SIZE, IN_CHAN), dtype=np.int32)
kernel = np.random.randint(-2, 2, size=(3, 3, IN_CHAN),               dtype=np.int32)

output = np.zeros((OUT_SIZE, OUT_SIZE), dtype=np.int32)

for r in range(OUT_SIZE):
    for c in range(OUT_SIZE):
        for kr in range(3):           # kernel spatial row
            for kc in range(3):       # kernel spatial col
                for ch in range(IN_CHAN):  # channel
                    # activation channel cycles with ch_cnt in hardware
                    act = int(image[r + kr][c + kc][ch])
                    wt  = int(kernel[kr][kc][ch])
                    output[r][c] += act * wt

with open("input_image.txt", "w") as f:
    for r in range(IMG_SIZE):
        for c in range(IMG_SIZE):
            for ch in range(IN_CHAN):
                f.write(f"{image[r][c][ch]}\n")

with open("input_kernel.txt", "w") as f:
    for kr in range(3):
        for kc in range(3):
            for ch in range(IN_CHAN):
                f.write(f"{kernel[kr][kc][ch]}\n")

with open("golden_output.txt", "w") as f:
    for r in range(OUT_SIZE):
        for c in range(OUT_SIZE):
            f.write(f"{output[r][c]}\n")

print(f"Output range: min={output.min()} max={output.max()}")
print("Files written successfully.")