import os

SHIFT = 16
SCALE = 1 << SHIFT

def to_signed(val):
    if val & 0x80000000: return val - 0x100000000
    return val

def load_hex(filename):
    if not os.path.exists(filename):
        print(f"Error: {filename} not found.")
        return []
    with open(filename, 'r') as f:
        return [to_signed(int(line.strip(), 16)) for line in f]

def fixed_mul(a, b):
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
    
    print(f"Processing Conv: {in_c}x{h_in}x{w_in} -> (s={stride}) -> {out_c}x{h_out}x{w_out}")

    for oc in range(out_c):
        for r_out in range(h_out):
            for c_out in range(w_out):
                r_in_start = (r_out * stride) - eff_pad
                c_in_start = (c_out * stride) - eff_pad
                
                acc = 0
                for ic in range(in_c):
                    for ky in range(k_size):
                        for kx in range(k_size):
                            r_in = r_in_start + ky
                            c_in = c_in_start + kx
                            
                            val = 0
                            if 0 <= r_in < h_in and 0 <= c_in < w_in:
                                val = input_vol[ic][r_in][c_in]
                            
                            w_val = weights[oc][ic][ky][kx]
                            acc += fixed_mul(val, w_val)
                
                acc += bias[oc]
                output_vol[oc][r_out][c_out] = acc
    return output_vol

def leaky_relu(input_vol, slope=0.2):
    slope_fixed = int(slope * 65536)
    c, h, w = len(input_vol), len(input_vol[0]), len(input_vol[0][0])
    out = [[[0]*w for _ in range(h)] for _ in range(c)]
    
    for i in range(c):
        for j in range(h):
            for k in range(w):
                val = input_vol[i][j][k]
                out[i][j][k] = fixed_mul(val, slope_fixed) if val < 0 else val
    return out

def load_weights_from_rom(rom_data, layer_idx, out_ch, in_ch, k=3):
    # Base address for this layer block
    base_addr = layer_idx * 16 
    
    # Check bounds
    if base_addr + 15 >= len(rom_data):
        print(f"Error: ROM index out of bounds. Layer {layer_idx} starts at {base_addr}, ROM size {len(rom_data)}")
        return [], []

    # Extract bias (Always at index 9 relative to base)
    bias = rom_data[base_addr+9]
    
    weights = []
    
    if k == 1:
        # 1x1 Convolution: Weight is at index 0. Indices 1-8 are padding.
        # We only need the first weight.
        w_val = rom_data[base_addr] 
        
        # Broadcast this single 1x1 filter to all requested channels
        for o in range(out_ch):
            row_in = []
            for i in range(in_ch):
                # 1x1 kernel is a single-element list of lists [[w]]
                row_in.append([[w_val]]) 
            weights.append(row_in)
            
    else:
        # 3x3 Convolution: Weights at indices 0-8
        w_block = rom_data[base_addr : base_addr+9]
        
        # Broadcast the single 3x3 filter to all requested channels
        for o in range(out_ch):
            row_in = []
            for i in range(in_ch):
                # Reshape flattened 9 weights to 3x3
                row_in.append([w_block[0:3], w_block[3:6], w_block[6:9]])
            weights.append(row_in)
        
    biases = [bias] * out_ch
    return weights, biases

def run():
    print("--- Discriminator Full Inference Simulation ---")
    
    flat_in = load_hex("tb_input_disc.hex")
    rom_data = load_hex("all_weights_disc.hex")
    
    if not flat_in or not rom_data: 
        print("Missing input files. Run disc_export.py first.")
        return

    DIM = 32
    input_vol = []
    idx = 0
    for c in range(3):
        plane = []
        for y in range(DIM):
            row = []
            for x in range(DIM):
                row.append(flat_in[idx]); idx += 1
            plane.append(row)
        input_vol.append(plane)
        
    # Layer 0: Neck
    w, b = load_weights_from_rom(rom_data, 0, 64, 3)
    x = conv2d(input_vol, w, b, stride=1)
    x = leaky_relu(x, 0.2)

    # Layers 1-7: Blocks
    # (In, Out, Stride)
    blocks = [
        (64, 64, 2),   (64, 128, 1),  (128, 128, 2), (128, 256, 1),
        (256, 256, 2), (256, 512, 1), (512, 512, 2)
    ]

    for i, (cin, cout, s) in enumerate(blocks):
        # Layer ID map: Neck=0, Blocks=1..7
        w, b = load_weights_from_rom(rom_data, i+1, cout, cin)
        x = conv2d(x, w, b, stride=s)
        x = leaky_relu(x, 0.2)

    # Layer 8: Final (1x1 Conv)
    # 512 input channels, 1 output channel
    w, b = load_weights_from_rom(rom_data, 8, 1, 512, k=1)
    x = conv2d(x, w, b, stride=1, pad=0, is_1x1=True)

    outfile = "inference_disc_out.hex"
    with open(outfile, 'w') as f:
        for c in x:
            for r in c:
                for val in r:
                    f.write(f"{(val & 0xFFFFFFFF):08X}\n")
                    
    print(f"Success. Output saved to {outfile}")

if __name__ == "__main__":
    run()