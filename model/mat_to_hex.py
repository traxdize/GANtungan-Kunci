#!/usr/bin/env python3
import os
import numpy as np
from scipy.io import loadmat

# Fixed-point config (match inference.py)
TOTAL_BITS = 16
FRAC = 8
SCALE = 2 ** FRAC

def float_to_q16(x):
    x = np.round(x * SCALE).astype(np.int32)
    maxv = 2**(TOTAL_BITS-1)-1
    minv = -2**(TOTAL_BITS-1)
    x = np.clip(x, minv, maxv).astype(np.int32)
    return x

def to_twos_hex(v, width=16):
    mask = (1 << width) - 1
    return '{:04x}'.format(int(v) & mask)

def write_row_files(prefix, W_fx, b_fx, out_dir):
    # W_fx: shape (OUT, IN)
    OUT, IN = W_fx.shape
    for r in range(OUT):
        wrow = W_fx[r, :]
        fname = os.path.join(out_dir, f"{prefix}_W_row{r}.hex")
        with open(fname, 'w') as f:
            for val in wrow:
                f.write(to_twos_hex(val) + '\n')
        # bias file (single entry)
        bname = os.path.join(out_dir, f"{prefix}_b_row{r}.hex")
        with open(bname, 'w') as f:
            f.write(to_twos_hex(b_fx[r]) + '\n')

def convert(mat_path, out_mem_dir=None):
    if out_mem_dir is None:
        out_mem_dir = os.path.join(os.path.dirname(__file__), '..', 'src', 'mem')
    out_mem_dir = os.path.abspath(out_mem_dir)
    os.makedirs(out_mem_dir, exist_ok=True)

    mat = loadmat(mat_path)
    # expected vars: Wg2,bg2,Wg3,bg3,Wd2,bd2,Wd3,bd3
    mappings = [
        ('Wg2','bg2','gen_s1'),
        ('Wg3','bg3','gen_s2'),
        ('Wd2','bd2','disc_s1'),
        ('Wd3','bd3','disc_s2'),
    ]

    for Wn, bn, prefix in mappings:
        if Wn not in mat or bn not in mat:
            raise KeyError(f"Missing {Wn} or {bn} in mat file")
        W = np.array(mat[Wn], dtype=np.float64)
        b = np.array(mat[bn], dtype=np.float64).reshape(-1)
        W_fx = float_to_q16(W)
        b_fx = float_to_q16(b)
        write_row_files(prefix, W_fx, b_fx, out_mem_dir)

    print(f"Wrote weight/bias hex files to {out_mem_dir}")

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser(description='Convert .mat GAN weights to Q1.7.8 hex files')
    p.add_argument('matfile', nargs='?', default=os.path.join(os.path.dirname(__file__), 'output', 'trained_simple_gan.mat'))
    p.add_argument('--out', '-o', default=None, help='output mem directory (default: ../src/mem)')
    args = p.parse_args()
    convert(args.matfile, args.out)
