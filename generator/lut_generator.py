import math
import argparse

def float_to_fixed(val, frac_bits):
    # Scale by 2^frac_bits
    scaled = int(val * (1 << frac_bits))
    
    # Clamp to 32-bit signed range (assuming Data Width is 32)
    limit_pos = 2147483647
    limit_neg = -2147483648
    
    if scaled > limit_pos: scaled = limit_pos
    if scaled < limit_neg: scaled = limit_neg
    
    # Convert to 32-bit hex (Two's complement)
    return f"{(scaled & 0xFFFFFFFF):08x}"

def generate_luts(frac_bits):
    # LUT Parameters
    address_bits = 10
    num_entries = 1 << address_bits

    # The step size remains 2^-7 because the Verilog logic 
    # slices [FRAC_WIDTH+2 : FRAC_WIDTH-7]
    step_size = 2.0**-7

    print(f"Generating LUTs for Q{32-frac_bits}.{frac_bits} | Step: {step_size} | Range: 0 to {num_entries * step_size}")

    with open("./src/mem/sigmoid_lut_mem.hex", "w") as f_sig, open("./src/mem/tanh_lut_mem.hex", "w") as f_tanh:
        for i in range(num_entries):
            # Input value based on index
            x = i * step_size

            # 1. Sigmoid: 1 / (1 + e^-x)
            sig_val = 1.0 / (1.0 + math.exp(-x))
            f_sig.write(float_to_fixed(sig_val, frac_bits) + "\n")

            # 2. Tanh: (e^x - e^-x) / (e^x + e^-x)
            tanh_val = math.tanh(x)
            f_tanh.write(float_to_fixed(tanh_val, frac_bits) + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate Fixed-Point LUTs")
    parser.add_argument("--frac_bits", type=int, default=24, help="Number of fractional bits (default: 24)")
    args = parser.parse_args()

    generate_luts(args.frac_bits)
    print(f"Generated sigmoid_lut_mem.hex and tanh_lut_mem.hex in Q{32-args.frac_bits}.{args.frac_bits} format.")