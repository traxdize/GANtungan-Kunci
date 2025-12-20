import math

def float_to_q16_16(val):
    # Scale by 2^16
    scaled = int(val * 65536)
    # Clamp to 32-bit signed range
    if scaled > 2147483647: scaled = 2147483647
    if scaled < -2147483648: scaled = -2147483648
    # Convert to 32-bit hex (Two's complement)
    return f"{(scaled & 0xFFFFFFFF):08x}"

def generate_luts():
    # LUT Parameters
    address_bits = 10
    num_entries = 1 << address_bits
    
    # Range configuration matching the Address Slicing in Verilog
    # Address is z[22:13]. 
    # Bit 16 is 2^0 (1.0). Bit 13 is 2^-3 (0.125).
    # Step size per address index is 0.125
    step_size = 2.0**-3 
    
    # The LUT typically covers positive indices directly. 
    # Logic in Verilog handles absolute value extraction for address.
    
    with open("sigmoid_lut_mem.hex", "w") as f_sig, open("tanh_lut_mem.hex", "w") as f_tanh:
        for i in range(num_entries):
            # Input value based on index
            x = i * step_size
            
            # 1. Sigmoid: 1 / (1 + e^-x)
            # Note: Verilog handles symmetry. We compute for positive x.
            sig_val = 1.0 / (1.0 + math.exp(-x))
            f_sig.write(float_to_q16_16(sig_val) + "\n")
            
            # 2. Tanh: (e^x - e^-x) / (e^x + e^-x)
            # Verilog logic handles the sign, we store result for positive x (or raw x)
            # However, standard Tanh LUTs usually store Tanh(x) for the address x.
            # Since the Verilog logic for Tanh handles negative inputs by passing 
            # the raw bits or handling sign, let's assume standard positive mapping
            # or symmetric mapping. 
            # Looking at original code: Tanh used raw address bits. 
            # Tanh(0) = 0.
            tanh_val = math.tanh(x)
            f_tanh.write(float_to_q16_16(tanh_val) + "\n")

if __name__ == "__main__":
    generate_luts()
    print("Generated sigmoid_lut_mem.hex and tanh_lut_mem.hex in Q16.16 format.")