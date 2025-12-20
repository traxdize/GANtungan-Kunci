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

def to_hex(val):
    """Converts signed int back to 32-bit hex string for display."""
    return f"{(val + 0x100000000) & 0xFFFFFFFF:08x}"

def q_mult(a, b):
    """Simulates Verilog: (a * b) >>> 16"""
    return (a * b) >> 16

def q_add(a, b):
    return a + b

def q_tanh(x):
    """Simulates Tanh LUT"""
    # Convert Q16.16 to float for tanh, then back
    float_val = x / 65536.0
    res = math.tanh(float_val)
    # Saturate like hardware
    if res >= 1.0: return 65536
    if res <= -1.0: return -65536
    return int(res * 65536)

# ==========================================
# 2. WEIGHTS (From previous chat)
# ==========================================
# Generator Hidden (G2)
wg2_1 = [hex_to_int('00000368'), hex_to_int('00000299')] # Neuron 1
bg2_1 = hex_to_int('00021391')

wg2_2 = [hex_to_int('0000202E'), hex_to_int('000003D2')] # Neuron 2
bg2_2 = hex_to_int('FFFFCCDC')

wg2_3 = [hex_to_int('FFFFDC57'), hex_to_int('FFFFEA04')] # Neuron 3
bg2_3 = hex_to_int('00008C1C')

# Generator Output (G3) - 9 Pixels
# Format: [w1, w2, w3], bias
g3_layer = [
    ([hex_to_int('FFFEC358'), hex_to_int('00000DA2'), hex_to_int('FFFFDAAA')], hex_to_int('FFFE2C0B')), # P1
    ([hex_to_int('0001479A'), hex_to_int('FFFFEDA0'), hex_to_int('000043B0')], hex_to_int('0001B139')), # P2
    ([hex_to_int('00017714'), hex_to_int('000013AD'), hex_to_int('000042BB')], hex_to_int('00019574')), # P3
    ([hex_to_int('00016FA4'), hex_to_int('00000F95'), hex_to_int('00002B78')], hex_to_int('0001A2D2')), # P4
    ([hex_to_int('FFFEAC8E'), hex_to_int('00003486'), hex_to_int('FFFFDA5C')], hex_to_int('FFFE4B6A')), # P5
    ([hex_to_int('000174EB'), hex_to_int('FFFFFCC6'), hex_to_int('00001F6B')], hex_to_int('0001A085')), # P6
    ([hex_to_int('000146E2'), hex_to_int('FFFFD31D'), hex_to_int('00003F63')], hex_to_int('0001B4AB')), # P7
    ([hex_to_int('00013BF6'), hex_to_int('FFFFFD25'), hex_to_int('000017A0')], hex_to_int('0001D914')), # P8
    ([hex_to_int('FFFED982'), hex_to_int('00003650'), hex_to_int('FFFFBD91')], hex_to_int('FFFE2D04')), # P9
]

# ==========================================
# 3. RUN SIMULATION
# ==========================================
print("--- Python Fixed-Point Verification ---")

# Inputs (Test Case 1 Noise)
# 0.5 and -0.2
noise_1 = hex_to_int('00008000') 
noise_2 = hex_to_int('FFFFCCCD') 

print(f"Input Noise 1: {noise_1/65536.0:.4f} (Hex: {to_hex(noise_1)})")
print(f"Input Noise 2: {noise_2/65536.0:.4f} (Hex: {to_hex(noise_2)})")

# --- Step A: Generator Hidden (G2) ---
print("\n=== G2 Hidden Layer (Calculated) ===")

# Neuron 1
sum1 = q_add(q_add(q_mult(noise_1, wg2_1[0]), q_mult(noise_2, wg2_1[1])), bg2_1)
g2_out1 = q_tanh(sum1)
print(f"Neuron 1 | Sum: {to_hex(sum1)} ({sum1/65536.0:+.4f}) -> Out: {to_hex(g2_out1)} ({g2_out1/65536.0:+.4f})")

# Neuron 2
sum2 = q_add(q_add(q_mult(noise_1, wg2_2[0]), q_mult(noise_2, wg2_2[1])), bg2_2)
g2_out2 = q_tanh(sum2)
print(f"Neuron 2 | Sum: {to_hex(sum2)} ({sum2/65536.0:+.4f}) -> Out: {to_hex(g2_out2)} ({g2_out2/65536.0:+.4f})")

# Neuron 3
sum3 = q_add(q_add(q_mult(noise_1, wg2_3[0]), q_mult(noise_2, wg2_3[1])), bg2_3)
g2_out3 = q_tanh(sum3)
print(f"Neuron 3 | Sum: {to_hex(sum3)} ({sum3/65536.0:+.4f}) -> Out: {to_hex(g2_out3)} ({g2_out3/65536.0:+.4f})")

# --- Step B: Generator Output (G3) ---
print("\n=== G3 Output Layer (Calculated) ===")
pixels = []
print(f"{'Px':<4} | {'Sum (Hex)':<10} {'Sum (Flt)':<10} | {'Out (Hex)':<10} {'Out (Flt)':<10}")
print("-" * 60)

for i, (weights, bias) in enumerate(g3_layer):
    # Sum = (g2_1 * w1) + (g2_2 * w2) + (g2_3 * w3) + bias
    s = q_mult(g2_out1, weights[0])
    s = q_add(s, q_mult(g2_out2, weights[1]))
    s = q_add(s, q_mult(g2_out3, weights[2]))
    s = q_add(s, bias)
    
    pix = q_tanh(s)
    pixels.append(pix)
    
    print(f"P{i+1:<3} | {to_hex(s)} {s/65536.0:>9.4f}  | {to_hex(pix)} {pix/65536.0:>9.4f}")

# Grid Visualization
print("\n=== Resulting Grid ===")
for i, pix in enumerate(pixels):
    val_float = pix / 65536.0
    # Determine symbol based on black/white threshold
    char = "X" if val_float > 0.5 else ("." if val_float < -0.5 else "?")
    
    if (i+1) % 3 == 0:
        print(f"{val_float:+.2f} {char}")
    else:
        print(f"{val_float:+.2f} {char}", end="\t")