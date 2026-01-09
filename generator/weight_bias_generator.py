# File          : weight_bias_generator.py
# Description   : Generates hex files for weights and biases from a .mat file

import scipy.io
import numpy as np
import os
import argparse

def to_hex(val):
    """Converts signed integer to 8-character 32-bit hex."""
    return f"{(int(val) + 0x100000000) & 0xFFFFFFFF:08x}"

def float_to_q16(val):
    return int(np.round(val * 65536))

def generate_hex_files(mat_path, output_dir="src/mem"):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    mat = scipy.io.loadmat(mat_path)
    
    # Initialize buffers for 32 addresses (matching MEM_DEPTH)
    depth = 32
    w_files = {f'w{i}': [0]*depth for i in range(1, 5)}
    bias_vals = [0]*depth

    # 1. G2 (Addr 0-2)
    for i in range(3):
        w_files['w1'][i] = float_to_q16(mat['Wg2'][i][0])
        w_files['w2'][i] = float_to_q16(mat['Wg2'][i][1])
        bias_vals[i]     = float_to_q16(mat['bg2'][i][0])

    # 2. G3 (Addr 3-11)
    for i in range(9):
        addr = 3 + i
        w_files['w1'][addr] = float_to_q16(mat['Wg3'][i][0])
        w_files['w2'][addr] = float_to_q16(mat['Wg3'][i][1])
        w_files['w3'][addr] = float_to_q16(mat['Wg3'][i][2])
        bias_vals[addr]     = float_to_q16(mat['bg3'][i][0])

    # 3. D2 (Addr 12-20)
    # Split 9 inputs across 3 passes: [w1,w2,w3,w4], [w5,w6,w7,w8], [w9,0,0,0]
    for i in range(3): # For each neuron
        base_addr = 12 + (i * 3)
        row = mat['Wd2'][i]
        
        # Pass 1 (w1-w4)
        w_files['w1'][base_addr] = float_to_q16(row[0])
        w_files['w2'][base_addr] = float_to_q16(row[1])
        w_files['w3'][base_addr] = float_to_q16(row[2])
        w_files['w4'][base_addr] = float_to_q16(row[3])
        
        # Pass 2 (w5-w8)
        w_files['w1'][base_addr+1] = float_to_q16(row[4])
        w_files['w2'][base_addr+1] = float_to_q16(row[5])
        w_files['w3'][base_addr+1] = float_to_q16(row[6])
        w_files['w4'][base_addr+1] = float_to_q16(row[7])
        
        # Pass 3 (w9 and Bias)
        w_files['w1'][base_addr+2] = float_to_q16(row[8])
        bias_vals[base_addr+2]     = float_to_q16(mat['bd2'][i][0])

    # 4. D3 (Addr 21)
    w_files['w1'][21] = float_to_q16(mat['Wd3'][0][0])
    w_files['w2'][21] = float_to_q16(mat['Wd3'][0][1])
    w_files['w3'][21] = float_to_q16(mat['Wd3'][0][2])
    bias_vals[21]     = float_to_q16(mat['bd3'][0][0])

    # Write to files
    for key, data in w_files.items():
        with open(f"{output_dir}/{key}.hex", "w") as f:
            f.write("\n".join([to_hex(x) for x in data]))

    with open(f"{output_dir}/bias.hex", "w") as f:
        f.write("\n".join([to_hex(x) for x in bias_vals]))

    print(f"Successfully generated 5 hex files in '{output_dir}/'")

if __name__ == "__main__":
    # mat_file is an argument when running the code
    parser = argparse.ArgumentParser(description="Generate hex files from a .mat file")
    parser.add_argument("mat_file", nargs="?", default="./generator/edge.mat",
                        help="Path to .mat file (default: ./generator/edge.mat)")
    args = parser.parse_args()

    generate_hex_files(args.mat_file)
    generate_hex_files(args.mat_file, output_dir="model")