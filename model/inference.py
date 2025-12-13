import numpy as np
from scipy.io import loadmat
import os

# 1. Fixed-Point Configuration
# Format: Q1.7.8 (Total 16 bits: 1 sign, 7 integer, 8 fractional)
TOTAL_BITS = 16
FRACTIONAL_BITS = 8
SCALING_FACTOR = 2**FRACTIONAL_BITS  # 2^8 = 256
MAT_FILE_PATH = "trained_simple_gan.mat"

# 2. Helper Functions for Fixed-Point Arithmetic

def float_to_fixed(f):
    """Converts a floating-point number to its scaled fixed-point integer representation."""
    scaled = np.round(f * SCALING_FACTOR).astype(np.int32)
    max_val = 2**(TOTAL_BITS - 1) - 1
    min_val = -2**(TOTAL_BITS - 1)
    return np.clip(scaled, min_val, max_val)

def fixed_to_float(i):
    """Converts a scaled fixed-point integer back to a float."""
    return i / SCALING_FACTOR

def fixed_matmul(W_fx, A_fx):
    """
    Performs fixed-point Matrix Multiplication (W @ A).
    The result is right-shifted by 'n' (FRACTIONAL_BITS) 
    to restore the Qm.n fixed-point format.
    """
    Z_wide = W_fx @ A_fx
    Z_fx = Z_wide // SCALING_FACTOR
    return Z_fx

# 3. Activation Functions (Fixed-Point Emulation)

def fixed_tanh(A_fx):
    A_float = fixed_to_float(A_fx)
    Z_float = np.tanh(A_float)
    return float_to_fixed(Z_float)

def fixed_sigmoid(A_fx):
    A_float = fixed_to_float(A_fx)
    Z_float = 1.0 / (1.0 + np.exp(-A_float))
    return float_to_fixed(Z_float)

# 4. Generator (G) Inference with Logging

def generator_inference(Wg2_fx, bg2_fx, Wg3_fx, bg3_fx, ng_float):
    print("\n## Generator Inference (Q1.7.8)")
    print("-" * 50)
    
    # Input: Latent Noise (ng)
    ng_fx = float_to_fixed(ng_float)
    print("Input (Latent Noise ng, Float):\n", fixed_to_float(ng_fx).T)

    # Layer 1: Hidden Layer (A_g2)
    Zg2_fx = fixed_matmul(Wg2_fx, ng_fx) + bg2_fx
    Ag2_fx = fixed_tanh(Zg2_fx)
    
    print("\nG Hidden Layer Output (Ag2)")
    print("Fixed-Point Integers (3 neurons):\n", Ag2_fx.T)
    print("Float Values:\n", fixed_to_float(Ag2_fx).T)

    # Layer 2: Output Layer (x_fake)
    Zg3_fx = fixed_matmul(Wg3_fx, Ag2_fx) + bg3_fx
    x_fake_fx = fixed_tanh(Zg3_fx) # Output image vector
    
    print("\nG Output Layer (x_fake)")
    print("Fixed-Point Integers (9 neurons):\n", x_fake_fx.T)
    print("Float Values (Image Vector):\n", fixed_to_float(x_fake_fx).T)

    return x_fake_fx

# 5. Discriminator (D) Inference with Logging

def discriminator_inference(Wd2_fx, bd2_fx, Wd3_fx, bd3_fx, x_fx):
    print("\n## Discriminator Inference (Q1.7.8)")
    print("-" * 50)
    
    # Input: Image Vector (x)
    print("Input (Image x, Float):\n", fixed_to_float(x_fx).T)

    # Layer 1: Hidden Layer (A_d2)
    Zd2_fx = fixed_matmul(Wd2_fx, x_fx) + bd2_fx
    Ad2_fx = fixed_tanh(Zd2_fx)
    
    print("\nD Hidden Layer Output (Ad2)")
    print("Fixed-Point Integers (3 neurons):\n", Ad2_fx.T)
    print("Float Values:\n", fixed_to_float(Ad2_fx).T)

    # Layer 2: Output Layer (y)
    Zd3_fx = fixed_matmul(Wd3_fx, Ad2_fx) + bd3_fx
    y_fx = fixed_sigmoid(Zd3_fx) # Probability output
    
    print("\nD Output Layer (y)")
    print("Fixed-Point Integer (1 neuron):\n", y_fx)
    print("Float Value (Probability):\n", fixed_to_float(y_fx))

    return y_fx

# 6. Data Loading and Conversion

def load_and_convert_weights(file_path):
    """Loads weights from .mat file and converts them to fixed-point integers."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Error: The file '{file_path}' was not found. Please ensure your MATLAB script has run and saved the file.")

    mat_data = loadmat(file_path)
    params_list = ['Wg2', 'bg2', 'Wg3', 'bg3', 'Wd2', 'bd2', 'Wd3', 'bd3']
    fixed_point_params = {}

    print(f"Loading parameters from: {file_path}")

    for name in params_list:
        float_data = mat_data[name].astype(np.float64)
        fx_data = float_to_fixed(float_data)
        fixed_point_params[name + '_fx'] = fx_data
        print(f"  Loaded and converted {name} (Shape: {float_data.shape})")

    return fixed_point_params

# 7. Main Execution

if __name__ == '__main__':
    try:
        # Load and convert all weights/biases
        params = load_and_convert_weights(MAT_FILE_PATH)

        # 1. Use the specific latent noise from the previous output trace
        ng_float = np.array([[0.05078125], [-0.015625]])

        # 2. Generator Inference
        x_fake_fx = generator_inference(
            params['Wg2_fx'], params['bg2_fx'], 
            params['Wg3_fx'], params['bg3_fx'], 
            ng_float
        )
        
        # Display the generated 3x3 image
        img_float = fixed_to_float(x_fake_fx).reshape(3, 3)
        print("\n**Generated 3x3 Image Visualization (-1=Black, 1=White):**")
        print(img_float)
        print("-" * 50)

        # 3. Discriminator Inference (using the generated image)
        y_fx = discriminator_inference(
            params['Wd2_fx'], params['bd2_fx'], 
            params['Wd3_fx'], params['bd3_fx'], 
            x_fake_fx
        )

        y_float = fixed_to_float(y_fx)
        print(f"\nFinal Probability: {y_float[0, 0]:.4f}")
        
    except FileNotFoundError as e:
        print(e)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
