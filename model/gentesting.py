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
    float_val = x / 65536.0
    res = math.tanh(float_val)
    if res >= 1.0: return 65536
    if res <= -1.0: return -65536
    return int(res * 65536)

def q_sigmoid(x):
    """Simulates Sigmoid LUT"""
    float_val = x / 65536.0
    try:
        res = 1.0 / (1.0 + math.exp(-float_val))
    except OverflowError:
        res = 0.0 if float_val < 0 else 1.0
        
    if res >= 1.0: return 65536
    if res <= 0.0: return 0
    return int(res * 65536)

# ==========================================
# 2. WEIGHTS (Extracted from memory.v)
# ==========================================
# --- Generator Weights (G2 & G3) ---
wg2_1 = [hex_to_int('00000368'), hex_to_int('00000299')]
bg2_1 = hex_to_int('00021391')
wg2_2 = [hex_to_int('0000202E'), hex_to_int('000003D2')]
bg2_2 = hex_to_int('FFFFCCDC')
wg2_3 = [hex_to_int('FFFFDC57'), hex_to_int('FFFFEA04')]
bg2_3 = hex_to_int('00008C1C')

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

# --- Discriminator Weights (D2 & D3) ---
# D2 Hidden (3 Neurons, 9 Inputs each)
# Weights are split across 3 passes in memory.v
# Order: P1..P4, P5..P8, P9..Bias
d2_weights = [
    # Neuron 1
    ([
        hex_to_int('000018EE'), hex_to_int('FFFFB014'), hex_to_int('FFFF9763'), hex_to_int('FFFFC48A'), # w1-w4
        hex_to_int('00004246'), hex_to_int('FFFFD8F0'), hex_to_int('FFFFB998'), hex_to_int('FFFFC6DF'), # w5-w8
        hex_to_int('00004301') # w9
    ], hex_to_int('0002115E')), # Bias
    # Neuron 2
    ([
        hex_to_int('FFFF8D34'), hex_to_int('0000452C'), hex_to_int('0000364F'), hex_to_int('000048C3'),
        hex_to_int('FFFFBBA9'), hex_to_int('00005C7F'), hex_to_int('00002735'), hex_to_int('00005BA1'),
        hex_to_int('FFFFC51B')
    ], hex_to_int('FFFD8C8B')),
    # Neuron 3
    ([
        hex_to_int('0000458B'), hex_to_int('FFFFD3E4'), hex_to_int('FFFFC879'), hex_to_int('FFFFB117'),
        hex_to_int('0000482C'), hex_to_int('FFFFB1BF'), hex_to_int('FFFFA595'), hex_to_int('FFFFBF41'),
        hex_to_int('00004A3A')
    ], hex_to_int('00024FFD'))
]

# D3 Output (1 Neuron, 3 Inputs)
d3_weights = ([hex_to_int('FFFDA679'), hex_to_int('0002BCA0'), hex_to_int('FFFD67DC')], hex_to_int('FFFEF456'))

# ==========================================
# 3. RUN SIMULATION
# ==========================================
print("--- Python Fixed-Point Verification (Full GAN) ---")

# Inputs (Test Case 1 Noise: 0.5, -0.2)
noise_1 = hex_to_int('00008000') 
noise_2 = hex_to_int('FFFFCCCD') 

print(f"Input Noise: {noise_1/65536.0:.4f}, {noise_2/65536.0:.4f}")

# --- Step A: Generator Hidden (G2) ---
print("\n=== G2 Hidden Layer ===")
g2_outs = []
for i, (w, b) in enumerate([(wg2_1, bg2_1), (wg2_2, bg2_2), (wg2_3, bg2_3)]):
    s = q_add(q_add(q_mult(noise_1, w[0]), q_mult(noise_2, w[1])), b)
    out = q_tanh(s)
    g2_outs.append(out)
    print(f"G2_N{i+1}: {to_hex(out)} ({out/65536.0:+.4f})")

# --- Step B: Generator Output (G3) ---
print("\n=== G3 Output Layer (Fake Image) ===")
g3_pixels = []
for i, (w, b) in enumerate(g3_layer):
    s = q_mult(g2_outs[0], w[0])
    s = q_add(s, q_mult(g2_outs[1], w[1]))
    s = q_add(s, q_mult(g2_outs[2], w[2]))
    s = q_add(s, b)
    pix = q_tanh(s)
    g3_pixels.append(pix)

# Print Grid
for i, pix in enumerate(g3_pixels):
    val_float = pix / 65536.0
    char = "X" if val_float > 0.5 else ("." if val_float < -0.5 else "?")
    end_char = "\n" if (i+1)%3==0 else "\t"
    print(f"{to_hex(pix)} {char}", end=end_char)

# --- Step C: Discriminator Hidden (D2) ---
print("\n=== D2 Hidden Layer (Discriminator) ===")
# D2 uses Tanh activation
d2_outs = []
for i, (weights, bias) in enumerate(d2_weights):
    s = bias
    for j, pixel_val in enumerate(g3_pixels):
        s = q_add(s, q_mult(pixel_val, weights[j]))
    
    out = q_tanh(s)
    d2_outs.append(out)
    print(f"D2_N{i+1}: {to_hex(out)} ({out/65536.0:+.4f})")

# --- Step D: Discriminator Output (D3) ---
print("\n=== D3 Output Layer (Final Probability) ===")
# D3 uses Sigmoid activation
w_d3, b_d3 = d3_weights
s_d3 = b_d3
s_d3 = q_add(s_d3, q_mult(d2_outs[0], w_d3[0]))
s_d3 = q_add(s_d3, q_mult(d2_outs[1], w_d3[1]))
s_d3 = q_add(s_d3, q_mult(d2_outs[2], w_d3[2]))

final_prob = q_sigmoid(s_d3)

print(f"Raw Sum:       {to_hex(s_d3)} ({s_d3/65536.0:+.4f})")
print(f"Final Output:  {to_hex(final_prob)}")
print(f"Probability:   {final_prob/65536.0:.4f}")