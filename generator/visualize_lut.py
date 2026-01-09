import math
import matplotlib.pyplot as plt
import numpy as np

def hex_to_float_q16_16(hex_str):
    """Converts a Q16.16 hex string (two's complement) back to a float."""
    val = int(hex_str, 16)
    if val & 0x80000000:
        val -= 0x100000000
    return val / 65536.0

def get_lut_value(lut, x, step_size, is_sigmoid=True):
    """Simulates hardware symmetry logic to retrieve values for negative x."""
    abs_x = abs(x)
    idx = int(abs_x / step_size)
    
    # Clamp index to LUT size
    if idx >= len(lut):
        idx = len(lut) - 1
    
    val = lut[idx]
    
    if x < 0:
        if is_sigmoid:
            # Sigmoid symmetry: f(-x) = 1 - f(x)
            return 1.0 - val
        else:
            # Tanh symmetry: f(-x) = -f(x)
            return -val
    return val

def plot_lut_comparison(filename, func, title, step_size, is_sigmoid):
    # Load LUT data
    lut = []
    try:
        with open(filename, "r") as f:
            lut = [hex_to_float_q16_16(line.strip()) for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Error: {filename} not found.")
        return

    # Define the range from -10 to 10
    x_range = np.linspace(-10, 10, 1000)
    ideal_vals = np.array([func(x) for x in x_range])
    
    # Simulate LUT access with symmetry
    lut_vals = np.array([get_lut_value(lut, x, step_size, is_sigmoid) for x in x_range])

    # Plotting
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), sharex=True, 
                                   gridspec_kw={'height_ratios': [3, 1]})

    ax1.plot(x_range, ideal_vals, label='Ideal (Math)', color='blue', alpha=0.6)
    ax1.step(x_range, lut_vals, label='LUT with Symmetry', color='red', linestyle='--', where='mid')
    ax1.set_ylabel('Output Value')
    ax1.set_title(f'{title} Activation (-10 to 10): Ideal vs Hardware LUT')
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    error = lut_vals - ideal_vals
    ax2.fill_between(x_range, error, color='purple', alpha=0.5)
    ax2.set_ylabel('Quant. Error')
    ax2.set_xlabel('Input Value (x)')
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.show()

def main():
    step_size = 2.0**-7

    # Sigmoid Comparison
    plot_lut_comparison(
        "./src/mem/sigmoid_lut_mem.hex", 
        lambda x: 1.0 / (1.0 + math.exp(-x)), 
        "Sigmoid", 
        step_size, 
        is_sigmoid=True
    )

    # Tanh Comparison
    plot_lut_comparison(
        "./src/mem/tanh_lut_mem.hex",
        math.tanh, 
        "Tanh", 
        step_size, 
        is_sigmoid=False
    )

if __name__ == "__main__":
    main()