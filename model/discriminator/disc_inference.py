import os

# ==========================================
# CONFIGURATION
# ==========================================
SHIFT = 16
SCALE = 1 << SHIFT

# ==========================================
# HEX HELPERS
# ==========================================
def to_signed(val):
    if val & 0x80000000: return val - 0x100000000
    return val

def load_hex(filename):
    path = os.path.join("mem_export_disc", filename)
    if not os.path.exists(path):
        print(f"ERROR: Missing {filename}")
        return []
    with open(path, 'r') as f:
        return [to_signed(int(line.strip(), 16)) for line in f]

# ==========================================
# MATH KERNELS (Bit-True)
# ==========================================
def fixed_mul(a, b):
    # Simulates (A * B) >>> 16 in Verilog
    return (a * b) >> SHIFT

def conv2d(input_vol, weights, bias, stride=1, pad=1, is_1x1=False):
    in_c = len(input_vol)
    h_in = len(input_vol[0])
    w_in = len(input_vol[0][0])
    out_c = len(weights)
    
    if is_1x1:
        h_out, w_out, k_size, eff_pad = h_in, w_in, 1, 0
    else:
        h_out, w_out, k_size, eff_pad = h_in // stride, w_in // stride, 3, pad

    output_vol = [[[0]*w_out for _ in range(h_out)] for _ in range(out_c)]
    
    print(f"    Processing Conv: {in_c}x{h_in}x{w_in} -> (s={stride}) -> {out_c}x{h_out}x{w_out}")

    for oc in range(out_c):
        for r_out in range(h_out):
            for c_out in range(w_out):
                
                # Calculate Input Window Position
                r_in_start = (r_out * stride) - eff_pad
                c_in_start = (c_out * stride) - eff_pad
                
                acc = 0
                
                # Convolve
                for ic in range(in_c):
                    for ky in range(k_size):
                        for kx in range(k_size):
                            r_in = r_in_start + ky
                            c_in = c_in_start + kx
                            
                            val = 0
                            # Zero Padding Logic
                            if 0 <= r_in < h_in and 0 <= c_in < w_in:
                                val = input_vol[ic][r_in][c_in]
                            
                            w_val = weights[oc][ic][ky][kx]
                            acc += fixed_mul(val, w_val)
                
                # Add Bias
                acc += bias[oc]
                output_vol[oc][r_out][c_out] = acc

    return output_vol

def leaky_relu(input_vol, slope=0.2):
    slope_fixed = int(slope * SCALE)
    c, h, w = len(input_vol), len(input_vol[0]), len(input_vol[0][0])
    out = [[[0]*w for _ in range(h)] for _ in range(c)]
    
    for i in range(c):
        for j in range(h):
            for k in range(w):
                val = input_vol[i][j][k]
                if val < 0:
                    out[i][j][k] = fixed_mul(val, slope_fixed)
                else:
                    out[i][j][k] = val
    return out

# ==========================================
# WEIGHT LOADER
# ==========================================
def load_weights_conv(name, out_ch, in_ch, k=3):
    flat_w = load_hex(f"{name}_weight.hex")
    flat_b = load_hex(f"{name}_bias.hex")
    
    weights = []
    idx = 0
    # Reshape Flat -> [Out][In][Ky][Kx]
    for o in range(out_ch):
        row_in = []
        for i in range(in_ch):
            row_k = []
            for y in range(k):
                row_x = []
                for x in range(k):
                    row_x.append(flat_w[idx])
                    idx += 1
                row_k.append(row_x)
            row_in.append(row_k)
        weights.append(row_in)
    return weights, flat_b

# ==========================================
# MAIN PIPELINE
# ==========================================
def run():
    print("--- Starting Hardware Inference Simulation ---")
    
    # 1. Load Input
    flat_in = load_hex("tb_input_disc.hex")
    DIM = 32
    input_vol = []
    idx = 0
    for c in range(3):
        plane = []
        for y in range(DIM):
            row = []
            for x in range(DIM):
                row.append(flat_in[idx])
                idx += 1
            plane.append(row)
        input_vol.append(plane)
        
    # 2. Layer: Neck
    w, b = load_weights_conv("neck_0", 64, 3)
    x = conv2d(input_vol, w, b, stride=1)
    x = leaky_relu(x, 0.2)

    # 3. Layer: Stem Blocks
    # (InCh, OutCh, Stride)
    blocks = [
        (64, 64, 2),   (64, 128, 1),  (128, 128, 2), (128, 256, 1),
        (256, 256, 2), (256, 512, 1), (512, 512, 2)
    ]

    for i, (cin, cout, s) in enumerate(blocks):
        print(f"--- Block {i} ---")
        w, b = load_weights_conv(f"stem_{i}_conv", cout, cin)
        x = conv2d(x, w, b, stride=s)
        x = leaky_relu(x, 0.2)

    # 4. Layer: Final 1x1 Conv
    print("--- Final Layer ---")
    w, b = load_weights_conv("stem_7", 1, 512, k=1)
    x = conv2d(x, w, b, stride=1, pad=0, is_1x1=True)

    # 5. Save Output
    outfile = "mem_export_disc/inference_disc_out.hex"
    with open(outfile, 'w') as f:
        for c in x:
            for r in c:
                for val in r:
                    f.write(f"{(val & 0xFFFFFFFF):08X}\n")
                    
    print(f"Success. Output saved to {outfile}")

if __name__ == "__main__":
    run()