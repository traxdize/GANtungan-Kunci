import math

# ==========================================
# 1. FIXED POINT MATH HELPERS (Q16.16)
# ==========================================
def hex_to_int(hex_str):
    """Converts 32-bit hex string (e.g., 'FFFFFA3B') to signed integer."""
    val = int(hex_str, 16)
    if val & 0x80000000: # If sign bit is set
        return val - 0x100000000
    return val

def q_mult(a, b):
    """Simulates Verilog: (a * b) >>> 16"""
    return (a * b) >> 16

def q_add(a, b):
    return a + b

def q_tanh(x):
    """Simulates Tanh LUT"""
    # Convert Q16.16 to float for tanh, then back
    # In hardware, this is a LUT, but math.tanh is close enough for verification
    float_val = x / 65536.0
    res = math.tanh(float_val)
    # Saturate like hardware
    if res >= 1.0: return 65536
    if res <= -1.0: return -65536
    return int(res * 65536)

# ==========================================
# 2. YOUR EXTRACTED WEIGHTS (From previous chat)
# ==========================================
# Generator Hidden (G2)
wg2_1 = [hex_to_int('FFFFFA3B'), hex_to_int('FFFFFEBE')] # Neuron 1
bg2_1 = hex_to_int('0001DE6D')

wg2_2 = [hex_to_int('00000073'), hex_to_int('FFFFFE3D')] # Neuron 2
bg2_2 = hex_to_int('0001A99D')

wg2_3 = [hex_to_int('FFFFF96E'), hex_to_int('FFFFFBC8')] # Neuron 3
bg2_3 = hex_to_int('FFFE8C63')

# Generator Output (G3) - 9 Pixels
# Format: [w1, w2, w3], bias
g3_layer = [
    ([hex_to_int('FFFF3C6B'), hex_to_int('FFFF41A0'), hex_to_int('0000B800')], hex_to_int('FFFF34F4')), # P1
    ([hex_to_int('0001635B'), hex_to_int('0000F01E'), hex_to_int('FFFF7723')], hex_to_int('000231C0')), # P2
    ([hex_to_int('FFFF7444'), hex_to_int('FFFF5910'), hex_to_int('0000C78A')], hex_to_int('FFFEF864')), # P3
    ([hex_to_int('00017B45'), hex_to_int('000100AF'), hex_to_int('FFFF6405')], hex_to_int('0001F850')), # P4
    ([hex_to_int('0000A9A8'), hex_to_int('0000E423'), hex_to_int('FFFF5977')], hex_to_int('0000D1C8')), # P5
    ([hex_to_int('000180B3'), hex_to_int('0000EDA4'), hex_to_int('FFFF57AB')], hex_to_int('0001FBE8')), # P6
    ([hex_to_int('FFFF56F9'), hex_to_int('FFFF29B9'), hex_to_int('0000C122')], hex_to_int('FFFF3A61')), # P7
    ([hex_to_int('0001407F'), hex_to_int('0000F4FF'), hex_to_int('FFFF4C7E')], hex_to_int('000229CC')), # P8
    ([hex_to_int('FFFF3474'), hex_to_int('FFFF5D78'), hex_to_int('00009BB0')], hex_to_int('FFFF0B52')), # P9
]

# ==========================================
# 3. RUN SIMULATION
# ==========================================
print("--- Python Fixed-Point Verification ---")

# Inputs (Test Case 1 Noise)
# 0.5 and -0.2
noise_1 = hex_to_int('00008000') 
noise_2 = hex_to_int('FFFFCCCD') 

print(f"Input Noise: {noise_1/65536.0:.4f}, {noise_2/65536.0:.4f}")

# --- Step A: Generator Hidden (G2) ---
# Neuron 1
sum1 = q_add(q_add(q_mult(noise_1, wg2_1[0]), q_mult(noise_2, wg2_1[1])), bg2_1)
g2_out1 = q_tanh(sum1)

# Neuron 2
sum2 = q_add(q_add(q_mult(noise_1, wg2_2[0]), q_mult(noise_2, wg2_2[1])), bg2_2)
g2_out2 = q_tanh(sum2)

# Neuron 3
sum3 = q_add(q_add(q_mult(noise_1, wg2_3[0]), q_mult(noise_2, wg2_3[1])), bg2_3)
g2_out3 = q_tanh(sum3)

print("\nG2 Hidden Layer Outputs:")
print(f"N1: {g2_out1/65536.0:.4f}")
print(f"N2: {g2_out2/65536.0:.4f}")
print(f"N3: {g2_out3/65536.0:.4f}")

# --- Step B: Generator Output (G3) ---
print("\nGenerated Image (Expect Cross Pattern):")
pixels = []
for i, (weights, bias) in enumerate(g3_layer):
    # Sum = (g2_1 * w1) + (g2_2 * w2) + (g2_3 * w3) + bias
    s = q_add(q_mult(g2_out1, weights[0]), q_mult(g2_out2, weights[1]))
    s = q_add(s, q_mult(g2_out3, weights[2]))
    s = q_add(s, bias)
    
    pix = q_tanh(s)
    pixels.append(pix)
    
    # Interpretation
    val_float = pix / 65536.0
    char = "X" if val_float > 0.5 else ("." if val_float < -0.5 else "?")
    
    # Print as grid
    if (i+1) % 3 == 0:
        print(f"{val_float:+.2f} ({char})")
    else:
        print(f"{val_float:+.2f} ({char})", end="\t")