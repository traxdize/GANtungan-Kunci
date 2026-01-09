import math
import matplotlib.pyplot as plt
import numpy as np
import os

# ==========================================
# 1. FIXED POINT MATH HELPERS (Q16.16)
# ==========================================
def hex_to_int(hex_str):
    """Converts 32-bit hex string (e.g., 'FFFFFA3B') to signed integer."""
    if not isinstance(hex_str, str) or not hex_str.strip(): return 0
    val = int(hex_str.strip(), 16)
    if val & 0x80000000: 
        return val - 0x100000000
    return val

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
# 2. GLOBAL WEIGHT LOADER
# ==========================================
def load_all_weights():
    print("--- Loading Weights from Single Hex Files ---")
    
    # Files to read
    files = ['w1.hex', 'w2.hex', 'w3.hex', 'w4.hex', 'bias.hex']
    data = {}
    
    # FIX: Get the absolute path to the folder containing this script
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
    except NameError:
        # Fallback for Jupyter/Interactive environments
        script_dir = os.getcwd()

    for fname in files:
        # Construct the full path
        path = os.path.join(script_dir, fname)
        
        if os.path.exists(path):
            print(f"  [OK] Found {fname}")
            with open(path, 'r') as f:
                data[fname] = [line.strip() for line in f if line.strip()]
        else:
            print(f"  [WARN] {fname} not found at {path}! Filling with zeros.")
            data[fname] = []

    # Helper to safely get a value at a specific index (row)
    def get_val(fname, index):
        if index < len(data[fname]):
            return hex_to_int(data[fname][index])
        return 0

    # --- PARSE LAYERS BASED ON MEMORY MAP ---
    
    # 1. Generator Hidden (G2) - Rows 0-2 (3 Neurons)
    g2_layer = []
    for i in range(0, 3):
        w = [get_val('w1.hex', i), get_val('w2.hex', i)]
        b = get_val('bias.hex', i)
        g2_layer.append((w, b))

    # 2. Generator Output (G3) - Rows 3-11 (9 Neurons)
    g3_layer = []
    for i in range(3, 12):
        w = [get_val('w1.hex', i), get_val('w2.hex', i), get_val('w3.hex', i)]
        b = get_val('bias.hex', i)
        g3_layer.append((w, b))

    # 3. Discriminator Hidden (D2) - Rows 12-20 (3 Neurons, 3 Passes each)
    d2_layer = []
    base_idx = 12
    for n in range(3): 
        # Pass 1
        p1_w = [get_val(f'w{k}.hex', base_idx) for k in range(1, 5)] 
        # Pass 2
        p2_w = [get_val(f'w{k}.hex', base_idx + 1) for k in range(1, 5)]
        # Pass 3
        p3_w = [get_val('w1.hex', base_idx + 2)] 
        
        full_weights = p1_w + p2_w + p3_w
        bias = get_val('bias.hex', base_idx + 2) 
        
        d2_layer.append((full_weights, bias))
        base_idx += 3

    # 4. Discriminator Output (D3) - Row 21 (1 Neuron)
    d3_layer = []
    idx = 21
    w = [get_val('w1.hex', idx), get_val('w2.hex', idx), get_val('w3.hex', idx)]
    b = get_val('bias.hex', idx)
    d3_layer.append((w, b))

    return g2_layer, g3_layer, d2_layer, d3_layer

# ==========================================
# 3. RUN SIMULATION
# ==========================================
print("\n--- Python Fixed-Point Verification ---")

# Load all layers
g2_layer, g3_layer, d2_layer, d3_layer = load_all_weights()

# Inputs (Test Case)
noise_1 = hex_to_int('00008000') # 0.5
noise_2 = hex_to_int('FFFFCCCD') # -0.2
inputs = [noise_1, noise_2]

# --- STEP A: Generator Hidden (G2) ---
g2_outputs = []
for weights, bias in g2_layer:
    acc = bias
    for i, w in enumerate(weights):
        if i < len(inputs):
            acc = q_add(acc, q_mult(inputs[i], w))
    g2_outputs.append(q_tanh(acc))

print(f"[G2] Output: {[x/65536.0 for x in g2_outputs]}")

# --- STEP B: Generator Output (G3) ---
fake_image_int = []
for weights, bias in g3_layer:
    acc = bias
    for i, w in enumerate(weights):
        if i < len(g2_outputs):
            acc = q_add(acc, q_mult(g2_outputs[i], w))
    fake_image_int.append(q_tanh(acc))

# Convert for Display
fake_image_float = [x / 65536.0 for x in fake_image_int]
print(f"[G3] Output: {fake_image_float}")

# --- VISUALIZATION ---
try:
    image_grid = np.array(fake_image_float).reshape(3, 3)
    plt.figure(figsize=(5, 5))
    plt.imshow(image_grid, cmap='gray', vmin=-1, vmax=1)
    plt.title(f"Generated Fake Image (3x3)\nNoise: [{noise_1/65536.0:.2f}, {noise_2/65536.0:.2f}]")
    plt.colorbar(label='Pixel Value')
    
    for i in range(3):
        for j in range(3):
            val = image_grid[i, j]
            text_color = 'white' if val < 0 else 'black'
            plt.text(j, i, f'{val:.3f}', ha='center', va='center', color=text_color, fontweight='bold')
    
    plt.xticks([])
    plt.yticks([])
    plt.show(block=False)
    plt.pause(1) 
except Exception as e:
    print(f"Plotting error: {e}")

# --- STEP C: Discriminator Hidden (D2) ---
d2_outputs = []
for weights, bias in d2_layer:
    acc = bias
    for i, w in enumerate(weights):
        if i < len(fake_image_int):
            acc = q_add(acc, q_mult(fake_image_int[i], w))
    d2_outputs.append(q_tanh(acc))

print(f"[D2] Output: {[x/65536.0 for x in d2_outputs]}")

# --- STEP D: Discriminator Output (D3) ---
d3_weights, d3_bias = d3_layer[0] 
d3_acc = d3_bias
for i, w in enumerate(d3_weights):
    if i < len(d2_outputs):
        d3_acc = q_add(d3_acc, q_mult(d2_outputs[i], w))

final_prob = q_sigmoid(d3_acc)

print(f"\n[D3] Probability: {final_prob/65536.0:.4f} (Hex: {hex(final_prob)})")