import math
import matplotlib.pyplot as plt
import numpy as np
import os

# ==========================================
# FIXED POINT MATH HELPERS (Q16.16)
# ==========================================

def hex_to_int(hex_str):
    """Converts 32-bit hex string (e.g., 'FFFFFA3B') to signed integer."""
    if not isinstance(hex_str, str) or not hex_str.strip(): return 0
    val = int(hex_str.strip(), 16)
    if val & 0x80000000: 
        return val - 0x100000000
    return val

def to_hex(val):
    """Converts int to 32-bit hex string."""
    return '0x' + format((val & 0xFFFFFFFF), '08X')

def to_float(val):
    """Converts Q16.16 int to float."""
    return val / 65536.0

def q_mult(a, b):
    return (a * b) >> 16

def q_add(a, b):
    return a + b

def q_tanh(x):
    float_val = x / 65536.0
    res = math.tanh(float_val)
    if res >= 1.0: return 65536
    if res <= -1.0: return -65536
    return int(res * 65536)

def q_sigmoid(x):
    float_val = x / 65536.0
    try:
        res = 1 / (1 + math.exp(-float_val))
    except OverflowError:
        res = 0 if float_val < 0 else 1
    
    if res >= 1.0: return 65536
    if res <= 0.0: return 0
    return int(res * 65536)

# ==========================================
# PRINT HELPERS
# ==========================================

def print_separator(title):
    print(f"\n{'='*60}")
    print(f" {title}")
    print(f"{'='*60}")

def print_layer_details(layer_name, neuron_idx, weights, bias, inputs, acc, output):
    w_str = ", ".join([f"{to_float(w):.4f}" for w in weights])
    in_str = ", ".join([f"{to_float(i):.4f}" for i in inputs])
    
    print(f" Neuron {neuron_idx}:")
    print(f"   Weights (Float): [{w_str}]")
    print(f"   Bias (Float):    {to_float(bias):.4f}")
    print(f"   Accumulator:     {to_float(acc):.4f} ({to_hex(acc)})")
    print(f"   Output:          {to_float(output):.4f} ({to_hex(output)})")
    print("-" * 60)

# ==========================================
# GLOBAL WEIGHT LOADER
# ==========================================

def load_all_weights():
    print("--- Loading Weights from Hex Files ---")
    
    # Files to read
    files = ['../src/mem/w1.hex', '../src/mem/w2.hex', '../src/mem/w3.hex', '../src/mem/w4.hex', '../src/mem/bias.hex']
    data = {}
    
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
    except NameError:
        script_dir = os.getcwd()

    for fname in files:
        path = os.path.join(script_dir, fname)
        if os.path.exists(path):
            with open(path, 'r') as f:
                data[fname] = [line.strip() for line in f if line.strip()]
        else:
            print(f"  [WARN] {fname} not found! Filling with zeros.")
            data[fname] = []

    def get_val(fname, index):
        if index < len(data[fname]):
            return hex_to_int(data[fname][index])
        return 0

    # --- PARSE LAYERS ---
    
    # 1. Generator Hidden (G2) - Rows 0-2 (3 Neurons)
    g2_layer = []
    for i in range(0, 3):
        w = [get_val('../src/mem/w1.hex', i), get_val('../src/mem/w2.hex', i)]
        b = get_val('../src/mem/bias.hex', i)
        g2_layer.append((w, b))

    # 2. Generator Output (G3) - Rows 3-11 (9 Neurons)
    g3_layer = []
    for i in range(3, 12):
        w = [get_val('../src/mem/w1.hex', i), get_val('../src/mem/w2.hex', i), get_val('../src/mem/w3.hex', i)]
        b = get_val('../src/mem/bias.hex', i)
        g3_layer.append((w, b))

    # 3. Discriminator Hidden (D2) - Rows 12-20 (3 Neurons, 3 Passes each)
    d2_layer = []
    base_idx = 12
    for n in range(3): 
        # Assemble 9 weights from multiple passes
        p1_w = [get_val(f'../src/mem/w{k}.hex', base_idx) for k in range(1, 5)] 
        p2_w = [get_val(f'../src/mem/w{k}.hex', base_idx + 1) for k in range(1, 5)]
        p3_w = [get_val('../src/mem/w1.hex', base_idx + 2)] 
        
        full_weights = p1_w + p2_w + p3_w
        bias = get_val('../src/mem/bias.hex', base_idx + 2) 
        
        d2_layer.append((full_weights, bias))
        base_idx += 3

    # 4. Discriminator Output (D3) - Row 21 (1 Neuron)
    d3_layer = []
    idx = 21
    w = [get_val('../src/mem/w1.hex', idx), get_val('../src/mem/w2.hex', idx), get_val('../src/mem/w3.hex', idx)]
    b = get_val('../src/mem/bias.hex', idx)
    d3_layer.append((w, b))

    return g2_layer, g3_layer, d2_layer, d3_layer

# ==========================================
# MAIN SIMULATION
# ==========================================

print_separator("FIXED POINT GAN VERIFICATION")

# Load Weights
g2_layer, g3_layer, d2_layer, d3_layer = load_all_weights()

# Inputs (Test Case)
noise_1 = hex_to_int('00008000') # 0.5
noise_2 = hex_to_int('FFFFCCCD') # -0.2
inputs = [noise_1, noise_2]

print(f"\nInitial Noise Input: [{to_float(noise_1)}, {to_float(noise_2)}]")

# --- STEP A: GENERATOR HIDDEN (G2) ---
print_separator("STEP A: Generator Hidden (G2) [2 Inputs -> 3 Neurons]")
g2_outputs = []

for idx, (weights, bias) in enumerate(g2_layer):
    acc = bias
    for i, w in enumerate(weights):
        if i < len(inputs):
            acc = q_add(acc, q_mult(inputs[i], w))
    
    out_val = q_tanh(acc)
    g2_outputs.append(out_val)
    
    print_layer_details("G2", idx, weights, bias, inputs, acc, out_val)


# --- STEP B: GENERATOR OUTPUT (G3) ---
print_separator("STEP B: Generator Output (G3) [3 Inputs -> 9 Pixels]")
fake_image_int = []

for idx, (weights, bias) in enumerate(g3_layer):
    acc = bias
    for i, w in enumerate(weights):
        if i < len(g2_outputs):
            acc = q_add(acc, q_mult(g2_outputs[i], w))
            
    out_val = q_tanh(acc)
    fake_image_int.append(out_val)
    
    # Only print details for first and last pixel to save space, or all if desired
    # Printing all for completeness as requested
    print_layer_details(f"Pixel {idx}", idx, weights, bias, g2_outputs, acc, out_val)

# Grid Visualization Data
fake_image_float = np.array([to_float(x) for x in fake_image_int]).reshape(3, 3)
g3_hex = np.array([to_hex(x) for x in fake_image_int]).reshape(3, 3)

print("\n--- Generated Image Grid (Float) ---")
for row in fake_image_float:
    print("  " + "  ".join(f"{v: .6f}" for v in row))

print("\n--- Generated Image Grid (Hex) ---")
for row in g3_hex:
    print("  " + "  ".join(row))


# --- STEP C: DISCRIMINATOR HIDDEN (D2) ---
print_separator("STEP C: Discriminator Hidden (D2) [9 Pixels -> 3 Neurons]")
d2_outputs = []

for idx, (weights, bias) in enumerate(d2_layer):
    acc = bias
    for i, w in enumerate(weights):
        if i < len(fake_image_int):
            acc = q_add(acc, q_mult(fake_image_int[i], w))
    
    out_val = q_tanh(acc)
    d2_outputs.append(out_val)
    
    print_layer_details("D2", idx, weights, bias, fake_image_int, acc, out_val)


# --- STEP D: DISCRIMINATOR OUTPUT (D3) ---
print_separator("STEP D: Discriminator Output (D3) [3 Inputs -> 1 Probability]")

d3_weights, d3_bias = d3_layer[0] 
d3_acc = d3_bias

for i, w in enumerate(d3_weights):
    if i < len(d2_outputs):
        d3_acc = q_add(d3_acc, q_mult(d2_outputs[i], w))

final_prob = q_sigmoid(d3_acc)

print_layer_details("D3 (Real/Fake)", 0, d3_weights, d3_bias, d2_outputs, d3_acc, final_prob)

print(f"\nFinal Probability: {to_float(final_prob):.6f}")
print(f"Final Hex Code:    {to_hex(final_prob)}")


# --- VISUALIZATION ---
try:
    image_grid = fake_image_float
    plt.figure(figsize=(6, 6))
    plt.imshow(image_grid, cmap='gray', vmin=-1, vmax=1)
    plt.title(f"Generated Fake Image (3x3)\nProb Real: {to_float(final_prob):.4f}")
    plt.colorbar(label='Pixel Value (-1 to 1)')
    
    for i in range(3):
        for j in range(3):
            val = image_grid[i, j]
            text_color = 'white' if val < 0 else 'black'
            plt.text(j, i, f'{val:.3f}', ha='center', va='center', color=text_color, fontweight='bold')
    
    print("\n[INFO] Displaying Plot...")
    plt.show()
except Exception as e:
    print(f"\n[Error] Plotting failed: {e}")