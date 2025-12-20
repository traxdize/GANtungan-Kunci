import scipy.io
import numpy as np

def to_fixed_hex(value):
    # Convert float to Q16.16 fixed point integer
    fixed_val = int(value * 65536)
    # Handle negative numbers (32-bit two's complement)
    if fixed_val < 0:
        fixed_val = (1 << 32) + fixed_val
    # Return 8-digit hex string
    return f"32'h{fixed_val & 0xFFFFFFFF:08X}"

def print_gan_params(mat_file):
    try:
        data = scipy.io.loadmat(mat_file)
    except Exception as e:
        print(f"Error loading {mat_file}: {e}")
        return

    print(f"--- Extracted Parameters from {mat_file} ---")
    
    # 1. Generator Hidden Layer (G2)
    Wg2 = data['Wg2']
    bg2 = data['bg2'].flatten()
    print("\n// Generator Hidden (G2) Weights")
    for i in range(Wg2.shape[0]):
        w1 = to_fixed_hex(Wg2[i, 0])
        w2 = to_fixed_hex(Wg2[i, 1])
        b  = to_fixed_hex(bg2[i])
        print(f"Neuron {i+1}: w1={w1}, w2={w2}, bias={b}")

    # 2. Generator Output Layer (G3)
    Wg3 = data['Wg3']
    bg3 = data['bg3'].flatten()
    print("\n// Generator Output (G3) Weights")
    for i in range(Wg3.shape[0]):
        w1 = to_fixed_hex(Wg3[i, 0])
        w2 = to_fixed_hex(Wg3[i, 1])
        w3 = to_fixed_hex(Wg3[i, 2])
        b  = to_fixed_hex(bg3[i])
        print(f"Pixel {i+1}:  w1={w1}, w2={w2}, w3={w3}, bias={b}")

    # 3. Discriminator Hidden Layer (D2)
    Wd2 = data['Wd2']
    bd2 = data['bd2'].flatten()
    print("\n// Discriminator Hidden (D2) Weights")
    for i in range(Wd2.shape[0]):
        # Pass 1
        w1 = to_fixed_hex(Wd2[i, 0]); w2 = to_fixed_hex(Wd2[i, 1])
        w3 = to_fixed_hex(Wd2[i, 2]); w4 = to_fixed_hex(Wd2[i, 3])
        print(f"Neuron {i+1} Pass 1: {w1}, {w2}, {w3}, {w4}")
        
        # Pass 2
        w1 = to_fixed_hex(Wd2[i, 4]); w2 = to_fixed_hex(Wd2[i, 5])
        w3 = to_fixed_hex(Wd2[i, 6]); w4 = to_fixed_hex(Wd2[i, 7])
        print(f"Neuron {i+1} Pass 2: {w1}, {w2}, {w3}, {w4}")
        
        # Pass 3
        w1 = to_fixed_hex(Wd2[i, 8]); b = to_fixed_hex(bd2[i])
        print(f"Neuron {i+1} Pass 3: {w1}, bias={b}")

    # 4. Discriminator Output Layer (D3)
    Wd3 = data['Wd3']
    bd3 = data['bd3'].flatten()
    print("\n// Discriminator Output (D3) Weights")
    w1 = to_fixed_hex(Wd3[0, 0])
    w2 = to_fixed_hex(Wd3[0, 1])
    w3 = to_fixed_hex(Wd3[0, 2])
    b  = to_fixed_hex(bd3[0])
    print(f"Output:     w1={w1}, w2={w2}, w3={w3}, bias={b}")

# Run the function
print_gan_params('trained_simple_gan.mat')