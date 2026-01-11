# File          : weight_bias_generator.py
# Description   : Generates hex files for weights/biases (Parameterized)

import scipy.io
import numpy as np
import os
import argparse

def to_hex(val):
    return f"{(int(val) + 0x100000000) & 0xFFFFFFFF:08x}"

def float_to_fixed(val, scale):
    return int(np.round(val * scale))

def generate_hex_files(mat_path, frac_bits, output_dir="src/mem"):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    scale = 1 << frac_bits
    print(f"Converting weights to Fixed Point Q{32-frac_bits}.{frac_bits} (Scale: {scale})")

    mat = scipy.io.loadmat(mat_path)
    depth = 32
    w_files = {f'w{i}': [0]*depth for i in range(1, 5)}
    bias_vals = [0]*depth

    # G2 (0-2)
    for i in range(3):
        w_files['w1'][i] = float_to_fixed(mat['Wg2'][i][0], scale)
        w_files['w2'][i] = float_to_fixed(mat['Wg2'][i][1], scale)
        bias_vals[i]     = float_to_fixed(mat['bg2'][i][0], scale)

    # G3 (3-11)
    for i in range(9):
        addr = 3 + i
        w_files['w1'][addr] = float_to_fixed(mat['Wg3'][i][0], scale)
        w_files['w2'][addr] = float_to_fixed(mat['Wg3'][i][1], scale)
        w_files['w3'][addr] = float_to_fixed(mat['Wg3'][i][2], scale)
        bias_vals[addr]     = float_to_fixed(mat['bg3'][i][0], scale)

    # D2 (12-20) split across passes
    for i in range(3):
        base_addr = 12 + (i * 3)
        row = mat['Wd2'][i]
        w_files['w1'][base_addr] = float_to_fixed(row[0], scale)
        w_files['w2'][base_addr] = float_to_fixed(row[1], scale)
        w_files['w3'][base_addr] = float_to_fixed(row[2], scale)
        w_files['w4'][base_addr] = float_to_fixed(row[3], scale)
        w_files['w1'][base_addr+1] = float_to_fixed(row[4], scale)
        w_files['w2'][base_addr+1] = float_to_fixed(row[5], scale)
        w_files['w3'][base_addr+1] = float_to_fixed(row[6], scale)
        w_files['w4'][base_addr+1] = float_to_fixed(row[7], scale)
        w_files['w1'][base_addr+2] = float_to_fixed(row[8], scale)
        bias_vals[base_addr+2]     = float_to_fixed(mat['bd2'][i][0], scale)

    # D3 (21)
    w_files['w1'][21] = float_to_fixed(mat['Wd3'][0][0], scale)
    w_files['w2'][21] = float_to_fixed(mat['Wd3'][0][1], scale)
    w_files['w3'][21] = float_to_fixed(mat['Wd3'][0][2], scale)
    bias_vals[21]     = float_to_fixed(mat['bd3'][0][0], scale)

    for key, data in w_files.items():
        with open(f"{output_dir}/{key}.hex", "w") as f:
            f.write("\n".join([to_hex(x) for x in data]))

    with open(f"{output_dir}/bias.hex", "w") as f:
        f.write("\n".join([to_hex(x) for x in bias_vals]))

    print(f"Wrote hex files to: {output_dir}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate hex files from .mat")
    parser.add_argument("mat_file", nargs="?", default="./generator/edge.mat")
    parser.add_argument("--frac_bits", type=int, default=24, help="Number of fractional bits (default: 24)")
    args = parser.parse_args()

    generate_hex_files(args.mat_file, args.frac_bits)
    # generate_hex_files(args.mat_file, args.frac_bits, output_dir="model") # Optional backup