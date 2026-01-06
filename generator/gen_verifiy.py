import os

SHIFT = 16
def to_signed(val):
    if val & 0x80000000: return val - 0x100000000
    return val

def fixed_mul(a, b):
    return (a * b) >> SHIFT

def run():
    print("--- Generator Hardware Simulation (Layer 0 Check) ---")
    
    if not os.path.exists("all_weights_gen.hex"):
        print("Error: all_weights_gen.hex not found!")
        return

    with open("all_weights_gen.hex", 'r') as f:
        rom_data = [to_signed(int(line.strip(), 16)) for line in f]

    base_addr = 0
    weights = rom_data[base_addr : base_addr+9]
    bias    = rom_data[base_addr + 9]
    slope   = rom_data[base_addr + 10]
    
    print(f"Layer 0 Parameters:")
    print(f"  Bias:  {bias} ({bias/65536.0:.4f})")
    print(f"  Slope: {slope} ({slope/65536.0:.4f})")
    
    input_pixels = [
        -65536, -63488, -61440,
        -63488, -61440, -59392,
        -61440, -59392, -57344
    ]
                    
    acc = 0
    print("\nCalculating Dot Product...")
    for i in range(9):
        prod = fixed_mul(input_pixels[i], weights[i])
        acc += prod
        print(f"  Tap {i}: Pix={input_pixels[i]} * W={weights[i]} = {prod}")
        
    acc += bias
    print(f"  Accumulated + Bias = {acc}")
    
    if acc < 0:
        out = fixed_mul(acc, slope)
    else:
        out = acc
    print(f"  Result (PReLU) = {out} (Float: {out/65536.0:.4f})")

if __name__ == "__main__":
    run()