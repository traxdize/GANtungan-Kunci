import scipy.io
import numpy as np
import os

def to_fixed_hex(value):
    """
    Convert float to Q16.16 fixed point integer (32-bit hex).
    Example: 1.0 -> 32'h00010000
    """
    # 1. Scale by 2^16 (65536)
    fixed_val = int(value * 65536)
    
    # 2. Handle negative numbers (32-bit two's complement)
    if fixed_val < 0:
        fixed_val = (1 << 32) + fixed_val
        
    # 3. Mask to 32 bits and return Verilog hex string
    return f"32'h{fixed_val & 0xFFFFFFFF:08X}"

def print_gan_params(mat_file_path):
    print(f"--- Loading: {mat_file_path} ---")
    
    if not os.path.exists(mat_file_path):
        print(f"CRITICAL ERROR: File not found at {mat_file_path}")
        return

    try:
        data = scipy.io.loadmat(mat_file_path)
    except Exception as e:
        print(f"Error reading .mat file: {e}")
        return

    # Debug: Print what keys are actually inside
    valid_keys = [k for k in data.keys() if not k.startswith('__')]
    print(f"Found variables: {valid_keys}")

    # --- 1. Generator Hidden Layer (G2) ---
    if 'Wg2' in data and 'bg2' in data:
        Wg2 = data['Wg2']
        bg2 = data['bg2'].flatten()
        print("\n// Generator Hidden (G2) Weights")
        for i in range(Wg2.shape[0]):
            # Safety check for dimensions
            if Wg2.shape[1] >= 2:
                w1 = to_fixed_hex(Wg2[i, 0])
                w2 = to_fixed_hex(Wg2[i, 1])
                b  = to_fixed_hex(bg2[i])
                print(f"Neuron {i+1}: w1={w1}, w2={w2}, bias={b}")
    else:
        print("\n[!] Skipping G2 (Wg2/bg2 not found)")

    # --- 2. Generator Output Layer (G3) ---
    if 'Wg3' in data and 'bg3' in data:
        Wg3 = data['Wg3']
        bg3 = data['bg3'].flatten()
        print("\n// Generator Output (G3) Weights")
        for i in range(Wg3.shape[0]):
            if Wg3.shape[1] >= 3:
                w1 = to_fixed_hex(Wg3[i, 0])
                w2 = to_fixed_hex(Wg3[i, 1])
                w3 = to_fixed_hex(Wg3[i, 2])
                b  = to_fixed_hex(bg3[i])
                print(f"Pixel {i+1}:  w1={w1}, w2={w2}, w3={w3}, bias={b}")
    else:
        print("\n[!] Skipping G3 (Wg3/bg3 not found)")

    # --- 3. Discriminator Hidden Layer (D2) ---
    if 'Wd2' in data and 'bd2' in data:
        Wd2 = data['Wd2']
        bd2 = data['bd2'].flatten()
        print("\n// Discriminator Hidden (D2) Weights")
        for i in range(Wd2.shape[0]):
            if Wd2.shape[1] >= 9:
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
    else:
         print("\n[!] Skipping D2 (Wd2/bd2 not found)")

    # --- 4. Discriminator Output Layer (D3) ---
    if 'Wd3' in data and 'bd3' in data:
        Wd3 = data['Wd3']
        bd3 = data['bd3'].flatten()
        print("\n// Discriminator Output (D3) Weights")
        if Wd3.shape[1] >= 3:
            w1 = to_fixed_hex(Wd3[0, 0])
            w2 = to_fixed_hex(Wd3[0, 1])
            w3 = to_fixed_hex(Wd3[0, 2])
            b  = to_fixed_hex(bd3[0])
            print(f"Output:     w1={w1}, w2={w2}, w3={w3}, bias={b}")
    else:
        print("\n[!] Skipping D3 (Wd3/bd3 not found)")

if __name__ == "__main__":
    # Get the folder where THIS script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Construct the full path to the .mat file
    # This ensures it works even if you run it from a different terminal location
    mat_path = os.path.join(script_dir, "trained_simple_gan.mat")
    
    print_gan_params(mat_path)