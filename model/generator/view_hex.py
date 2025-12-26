import numpy as np
import matplotlib.pyplot as plt
import os

# ==========================================
# CONFIGURATION
# ==========================================
# File Paths
FILE_INPUT    = "mem_export/tb_input_image.hex"
FILE_GOLDEN   = "mem_export/tb_golden_output.hex"
FILE_INFER    = "mem_export/barebones_out.hex"  # Output from barebones_inference.py

# Dimensions
INPUT_RES     = 8   # 8x8 Input
OUTPUT_RES    = 32  # 8x8 * 2 * 2 = 32x32 Output
CHANNELS      = 3

def hex_to_float(hex_lines):
    """
    Parses Q16.16 Hex strings into Floating point list.
    Example: '00010000' -> 65536 -> 1.0
    """
    values = []
    for line in hex_lines:
        line = line.strip()
        if not line: continue
        
        # Parse Hex to 32-bit int
        val_int = int(line, 16)
        
        # Handle 2's Complement (Signed 32-bit)
        if val_int & 0x80000000:
            val_int = val_int - 0x100000000
            
        # Convert Q16.16 to Float
        values.append(val_int / 65536.0)
    return values

def load_image(filepath, res):
    """Reads hex file and reshapes to (Height, Width, Channels)"""
    if not os.path.exists(filepath):
        print(f"Warning: File not found: {filepath}")
        return np.zeros((res, res, 3))

    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    data = hex_to_float(lines)
    
    expected = CHANNELS * res * res
    if len(data) != expected:
        print(f"Warning: {filepath} has {len(data)} values, expected {expected}. Padding/Truncating.")
        # Handle mismatch gracefully for visualization
        if len(data) < expected:
            data += [0] * (expected - len(data))
        else:
            data = data[:expected]

    # Reshape: (Channels, Height, Width) -> (Height, Width, Channels)
    # Your export scripts save in Channel-First order (R..G..B..)
    img = np.array(data).reshape((CHANNELS, res, res))
    img = img.transpose(1, 2, 0)
    return img

def denormalize(img):
    """
    Convert [-1, 1] range to [0, 1] for Matplotlib.
    """
    return np.clip((img + 1.0) / 2.0, 0.0, 1.0)

def main():
    print("--- Visualizing HEX Data ---")
    
    # 1. Load Data
    print(f"Loading Input ({INPUT_RES}x{INPUT_RES})...")
    img_in = load_image(FILE_INPUT, INPUT_RES)
    
    print(f"Loading Golden ({OUTPUT_RES}x{OUTPUT_RES})...")
    img_gold = load_image(FILE_GOLDEN, OUTPUT_RES)
    
    print(f"Loading Inference ({OUTPUT_RES}x{OUTPUT_RES})...")
    img_inf = load_image(FILE_INFER, OUTPUT_RES)

    # 2. Post-Processing
    # Input: Already normalized -1 to 1 (if using gradient/noise). Just denorm.
    img_in_show = denormalize(img_in)

    # Golden: PyTorch output already includes Tanh. Just denorm.
    img_gold_show = denormalize(img_gold)

    # Inference: Barebones script SKIPPED Tanh. We must apply it here.
    # Otherwise, values are huge (e.g. 50.0) and will display as pure white/black.
    img_inf_tanh = np.tanh(img_inf) 
    img_inf_show = denormalize(img_inf_tanh)

    # 3. Calculate Error (Pixel Difference)
    # We compare the Tanh'd versions
    diff = np.abs(img_gold - img_inf_tanh)
    avg_error = np.mean(diff)
    print(f"Average Pixel Error (Golden vs Inference): {avg_error:.6f}")

    # 4. Plotting
    fig, axes = plt.subplots(1, 3, figsize=(15, 6))
    
    # Plot Input
    axes[0].imshow(img_in_show, interpolation='nearest')
    axes[0].set_title("1. Input (Low Res)")
    axes[0].axis('off')

    # Plot Golden
    axes[1].imshow(img_gold_show, interpolation='nearest')
    axes[1].set_title("2. Golden Model (PyTorch)")
    axes[1].axis('off')

    # Plot Inference
    axes[2].imshow(img_inf_show, interpolation='nearest')
    axes[2].set_title(f"3. Barebones Fixed Point Inference\n(Avg Err: {avg_error:.4f})")
    axes[2].axis('off')

    plt.tight_layout()
    plt.savefig("mem_export/comparison_view.png")
    print("Saved comparison to mem_export/comparison_view.png")
    plt.show()

if __name__ == "__main__":
    main()