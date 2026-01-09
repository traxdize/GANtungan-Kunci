import math

def float_to_q8_24(val):
    # Scale by 2^24
    scaled = int(val * (1 << 24))
    # Clamp to 32-bit signed range
    if scaled > 2147483647: scaled = 2147483647
    if scaled < -2147483648: scaled = -2147483648
    # Convert to 32-bit hex (Two's complement)
    return f"{(scaled & 0xFFFFFFFF):08x}"

def generate_luts():
    # LUT Parameters
    address_bits = 10
    num_entries = 1 << address_bits

    step_size = 2.0**-7

    print(f"Generating LUTs with step_size: {step_size} (Range: 0 to {num_entries * step_size}) in Q8.24 format")

    with open("./src/mem/sigmoid_lut_mem.hex", "w") as f_sig, open("./src/mem/tanh_lut_mem.hex", "w") as f_tanh:
        for i in range(num_entries):
            # Input value based on index
            x = i * step_size

            # 1. Sigmoid: 1 / (1 + e^-x)
            sig_val = 1.0 / (1.0 + math.exp(-x))
            f_sig.write(float_to_q8_24(sig_val) + "\n")

            # 2. Tanh: (e^x - e^-x) / (e^x + e^-x)
            # Tanh is symmetric. We generate for positive x.
            tanh_val = math.tanh(x)
            f_tanh.write(float_to_q8_24(tanh_val) + "\n")

if __name__ == "__main__":
    generate_luts()
    print("Generated sigmoid_lut_mem.hex and tanh_lut_mem.hex in Q8.24 format.")