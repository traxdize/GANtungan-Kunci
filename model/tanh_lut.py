import numpy as np
import pandas as pd

# Configuration
LUT_FILE_PATH = "output/tanh_lut_q1_7_8.csv"
HEX_FILE_PATH = "output/tanh_lut_mem.hex"
FRACTIONAL_BITS = 8
SCALING_FACTOR = 2**FRACTIONAL_BITS

ADDRESS_BITS = 10
NUM_ENTRIES = 2**ADDRESS_BITS
INPUT_RANGE_MIN = -5.0
INPUT_RANGE_MAX = 5.0

def float_to_fixed(f):
    scaled = np.round(f * SCALING_FACTOR)
    max_val = (2**15) - 1
    min_val = -(2**15)
    return np.clip(scaled, min_val, max_val).astype(np.int32)

# Generate LUT
print(f"Generating Tanh LUT with {NUM_ENTRIES} entries...")
Z_float = np.linspace(INPUT_RANGE_MIN, INPUT_RANGE_MAX, NUM_ENTRIES)
tanh_float = np.tanh(Z_float)
tanh_fixed = float_to_fixed(tanh_float)

# Save to CSV
data = {
    'Address_Index': np.arange(NUM_ENTRIES),
    'Input_Z_Sample': Z_float,
    'Output_Tanh': tanh_float,
    'LUT_Value_Q1_7_8': tanh_fixed
}

df_lut = pd.DataFrame(data)
df_lut.to_csv(LUT_FILE_PATH, index=False, float_format='%.8f')
print(f"Saved Tanh LUT to: {LUT_FILE_PATH}")

# Convert to HEX file
with open(HEX_FILE_PATH, 'w') as f:
    for value in tanh_fixed:
        hex_str = format(value & 0xFFFF, '04x')
        f.write(f"{hex_str}\n")
print(f"Generated memory file: {HEX_FILE_PATH}")

# Display samples
print("\nFirst 5 entries:")
print(df_lut.head())
print("\nLast 5 entries:")
print(df_lut.tail())