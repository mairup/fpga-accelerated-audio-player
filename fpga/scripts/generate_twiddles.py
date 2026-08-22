#!/usr/bin/env python3
import math

def generate_twiddles(N=1024, width=12):
    max_val = (1 << (width - 1)) - 1  # 2047 for 12-bit
    min_val = -(1 << (width - 1))     # -2048 for 12-bit
    mask = (1 << width) - 1

    lines = []
    for k in range(N):
        theta = 2.0 * math.pi * k / N
        cos_val = math.cos(theta)
        sin_val = -math.sin(theta)  # W_N^k = e^(-j 2 pi k / N) = cos - j sin

        re_int = round(cos_val * max_val)
        im_int = round(sin_val * max_val)

        # Clamp
        re_int = max(min_val, min(max_val, re_int))
        im_int = max(min_val, min(max_val, im_int))

        re_hex = f"{re_int & mask:03X}"
        im_hex = f"{im_int & mask:03X}"

        lines.append(f"        wn_re[{k:4d}] = 12'h{re_hex}; wn_im[{k:4d}] = 12'h{im_hex};")
    return "\n".join(lines)

if __name__ == "__main__":
    twiddles = generate_twiddles()
    print("Generated 1024 twiddles. Sample:")
    print("\n".join(twiddles.splitlines()[:10]))
    print("...")
    print("\n".join(twiddles.splitlines()[-5:]))
