import os

# ==========================================
# 0. CONFIGURATION & HELPERS
# ==========================================

# Fixed-Point Params (Q16.16)
SHIFT = 16
SCALE = 1 << SHIFT  # 65536
MAX_INT = (1 << 31) - 1
MIN_INT = -(1 << 31)

def to_signed(val):
    """Interpret 32-bit hex as signed integer."""
    if val & 0x80000000:
        return val - 0x100000000
    return val

def to_hex(val):
    """Format integer as 32-bit hex."""
    return f"{(val & 0xFFFFFFFF):08X}"

def load_hex_file(filename):
    """Reads a hex file into a list of integers."""
    path = os.path.join("mem_export", filename)
    if not os.path.exists(path):
        print(f"ERROR: Missing {filename}")
        return []
    with open(path, 'r') as f:
        return [to_signed(int(line.strip(), 16)) for line in f]

# ==========================================
# 1. MATH KERNELS (The "Hardware" Logic)
# ==========================================

def fixed_mul(a, b):
    """
    Hardware Multiply: (A * B) >> 16
    Simulates the DSP slice behavior.
    """
    res = (a * b) >> SHIFT
    return res

def conv2d_3x3(input_vol, weights, bias, stride=1, pad=1):
    """
    Standard 3x3 Convolution with Padding.
    Matches the hardware sliding window logic.
    """
    in_c = len(input_vol)
    h = len(input_vol[0])
    w = len(input_vol[0][0])
    
    # weights structure: [OutC][InC][3][3]
    out_c = len(weights)
    
    # Output dimensions (assuming pad=1, stride=1 preserves size)
    out_h = h 
    out_w = w 
    
    # Initialize output volume with zeros
    output_vol = [[[0]*out_w for _ in range(out_h)] for _ in range(out_c)]
    
    print(f"    > Conv3x3: In({in_c}x{h}x{w}) -> Out({out_c}x{out_h}x{out_w})")

    for oc in range(out_c):
        for r in range(out_h):
            for c in range(out_w):
                acc = 0
                
                # Iterate over input channels
                for ic in range(in_c):
                    # 3x3 Window
                    for ky in range(3):
                        for kx in range(3):
                            # Calculate Input Indices (with padding logic)
                            in_r = r - pad + ky
                            in_c_idx = c - pad + kx
                            
                            val = 0 # Default padding value (Zero Padding)
                            if 0 <= in_r < h and 0 <= in_c_idx < w:
                                val = input_vol[ic][in_r][in_c_idx]
                            
                            w_val = weights[oc][ic][ky][kx]
                            
                            # Multiply-Accumulate (MAC)
                            prod = fixed_mul(val, w_val)
                            acc += prod
                
                # Add Bias
                acc += bias[oc]
                output_vol[oc][r][c] = acc
                
    return output_vol

def prelu(input_vol, slope):
    """
    Parametric ReLU: if x < 0: x * slope
    """
    c = len(input_vol)
    h = len(input_vol[0])
    w = len(input_vol[0][0])
    
    out = [[[0]*w for _ in range(h)] for _ in range(c)]
    
    for ch in range(c):
        # Slope is typically a single scalar for the whole layer in SRGAN
        s = slope 
        
        for r in range(h):
            for c_idx in range(w):
                val = input_vol[ch][r][c_idx]
                if val < 0:
                    out[ch][r][c_idx] = fixed_mul(val, s)
                else:
                    out[ch][r][c_idx] = val
    return out

def pixel_shuffle(input_vol, scale=2):
    """
    Rearranges (C*r*r, H, W) to (C, H*r, W*r).
    Pure addressing logic, no math involved.
    """
    in_c = len(input_vol)
    in_h = len(input_vol[0])
    in_w = len(input_vol[0][0])
    
    out_c = in_c // (scale * scale)
    out_h = in_h * scale
    out_w = in_w * scale
    
    output_vol = [[[0]*out_w for _ in range(out_h)] for _ in range(out_c)]
    
    for oc in range(out_c):
        for r in range(out_h):
            for c in range(out_w):
                # Inverse mapping to find source pixel
                src_r = r // scale
                src_c = c // scale
                
                rem_r = r % scale
                rem_c = c % scale
                
                # PyTorch PixelShuffle Formula
                # src_ch = oc * (r^2) + rem_r * r + rem_c
                src_ch = oc * (scale*scale) + (rem_r * scale) + rem_c
                
                output_vol[oc][r][c] = input_vol[src_ch][src_r][src_c]
                
    return output_vol

def add_residual(vol_a, vol_b):
    """Element-wise addition for Skip Connections."""
    c = len(vol_a)
    h = len(vol_a[0])
    w = len(vol_a[0][0])
    out = [[[0]*w for _ in range(h)] for _ in range(c)]
    
    for i in range(c):
        for j in range(h):
            for k in range(w):
                out[i][j][k] = vol_a[i][j][k] + vol_b[i][j][k]
    return out

# ==========================================
# 2. WEIGHT LOADER (Parses Hex to Structure)
# ==========================================
def load_conv_weights(name, out_ch, in_ch):
    flat_w = load_hex_file(f"{name}_weight.hex")
    flat_b = load_hex_file(f"{name}_bias.hex")
    
    # Reshape Flat List -> [Out][In][3][3]
    # This loop defines exactly how the weights are stored in the hex file
    weights = []
    idx = 0
    for o in range(out_ch):
        row_in = []
        for i in range(in_ch):
            row_k = []
            for y in range(3):
                row_x = []
                for x in range(3):
                    row_x.append(flat_w[idx])
                    idx += 1
                row_k.append(row_x)
            row_in.append(row_k)
        weights.append(row_in)
        
    return weights, flat_b

def load_prelu_slope(name):
    # Reads single scalar slope
    data = load_hex_file(f"{name}_weight.hex")
    if not data: return 0
    return data[0]

# ==========================================
# 3. MAIN PIPELINE (The "Testbench")
# ==========================================

def run():
    print("--- 1. Loading Input Image ---")
    flat_img = load_hex_file("tb_input_image.hex")
    
    # Reshape 1D -> 3x8x8 (Assuming 8x8 input for testing)
    input_vol = []
    idx = 0
    for c in range(3):
        plane = []
        for y in range(8):
            row = []
            for x in range(8):
                row.append(flat_img[idx])
                idx += 1
            plane.append(row)
        input_vol.append(plane)
        
    print("--- 2. Running Generator ---")
    
    # LAYER: NECK (Conv + PReLU)
    w, b = load_conv_weights("neck_0", 64, 3)
    x = conv2d_3x3(input_vol, w, b)
    
    slope = load_prelu_slope("neck_1")
    x = prelu(x, slope)
    
    resid_base = x # Store for later (Global Skip Connection)
    
    # LAYER: STEM (8 Residual Blocks)
    for i in range(8):
        print(f"  [Block {i}]")
        identity = x
        
        # Conv 1
        w, b = load_conv_weights(f"stem_{i}_conv1", 64, 64)
        x = conv2d_3x3(x, w, b)
        
        # PReLU
        slope = load_prelu_slope(f"stem_{i}_relu1")
        x = prelu(x, slope)
        
        # Conv 2
        w, b = load_conv_weights(f"stem_{i}_conv2", 64, 64)
        x = conv2d_3x3(x, w, b)
        
        # Add Skip Connection
        x = add_residual(x, identity)
        
    # LAYER: BOTTLENECK
    print("  [Bottleneck]")
    w, b = load_conv_weights("bottleneck_0", 64, 64)
    x = conv2d_3x3(x, w, b)
    x = add_residual(x, resid_base)
    
    # LAYER: UPSAMPLING 1 (x2)
    print("  [Upsample 1]")
    w, b = load_conv_weights("upsampling_0_conv", 256, 64)
    x = conv2d_3x3(x, w, b)
    x = pixel_shuffle(x, 2)
    slope = load_prelu_slope("upsampling_0_relu")
    x = prelu(x, slope)
    
    # LAYER: UPSAMPLING 2 (x2)
    print("  [Upsample 2]")
    w, b = load_conv_weights("upsampling_1_conv", 256, 64)
    x = conv2d_3x3(x, w, b)
    x = pixel_shuffle(x, 2)
    slope = load_prelu_slope("upsampling_1_relu")
    x = prelu(x, slope)
    
    # LAYER: HEAD (To RGB)
    print("  [Head]")
    w, b = load_conv_weights("head_0", 3, 64)
    x = conv2d_3x3(x, w, b)
    
    # LAYER: TANH (Approximation/Skip)
    # Often skipped in hardware debugging to see raw values, 
    # but you can implement a LUT lookup here if needed.
    
    print("--- 3. Saving Output ---")
    with open("mem_export/barebones_out.hex", 'w') as f:
        for c in range(3):
            for y in range(len(x[0])):
                for val in x[c][y]:
                    f.write(to_hex(val) + '\n')
    print("Done. Saved to mem_export/barebones_out.hex")

if __name__ == "__main__":
    run()