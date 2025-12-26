import torch
import torch.nn as nn
import numpy as np
import os

# ==========================================
# 0. CONFIGURATION & SEEDS
# ==========================================
class Config:
    def __init__(self):
        self.n_filters = 64
        self.n_layers = 8

def set_seeds():
    torch.manual_seed(42)
    np.random.seed(42)

# ==========================================
# 1. MODEL DEFINITION
# ==========================================
class ResidualBlock(nn.Module):
    def __init__(self, in_channels, out_channels):
        super().__init__()
        self.conv1 = nn.Conv2d(in_channels, out_channels, 3, 1, 1, bias=False)
        self.bn1 = nn.BatchNorm2d(out_channels)
        self.relu1 = nn.PReLU()
        self.conv2 = nn.Conv2d(in_channels, out_channels, 3, 1, 1, bias=False)
        self.bn2 = nn.BatchNorm2d(out_channels)

    def forward(self, x):
        y = self.relu1(self.bn1(self.conv1(x)))
        return self.bn2(self.conv2(y)) + x

class UpSamplingBlock(nn.Module):
    def __init__(self, config):
        super().__init__()
        self.conv = nn.Conv2d(config.n_filters, config.n_filters * 4, 3, 1, 1)
        self.phase_shift = nn.PixelShuffle(upscale_factor=2)
        self.relu = nn.PReLU()

    def forward(self, x):
        return self.relu(self.phase_shift(self.conv(x)))

class Generator(nn.Module):
    def __init__(self, config):
        super().__init__()
        self.neck = nn.Sequential(
            nn.Conv2d(3, config.n_filters, 3, 1, 1),
            nn.PReLU(),
        )
        self.stem = nn.Sequential(
            *[ResidualBlock(config.n_filters, config.n_filters) for _ in range(config.n_layers)]
        )
        self.bottleneck = nn.Sequential(
            nn.Conv2d(config.n_filters, config.n_filters, 3, 1, 1, bias=False),
            nn.BatchNorm2d(config.n_filters),
        )
        self.upsampling = nn.Sequential(
            UpSamplingBlock(config),
            UpSamplingBlock(config),
        )
        self.head = nn.Sequential(
            nn.Conv2d(config.n_filters, 3, 3, 1, 1),
            nn.Tanh(),
        )

    def forward(self, x):
        residual = self.neck(x)
        x = self.stem(residual)
        x = self.bottleneck(x) + residual
        x = self.upsampling(x)
        return self.head(x)

# ==========================================
# 2. HELPER FUNCTIONS
# ==========================================

def fuse_bn_sequential(block):
    """Fuses BatchNorm layers into preceding Conv layers for hardware optimization."""
    stack = []
    for m in block.children():
        if isinstance(m, nn.Conv2d):
            stack.append(m)
        elif isinstance(m, nn.BatchNorm2d):
            if stack and isinstance(stack[-1], nn.Conv2d):
                conv = stack.pop()
                bn = m
                with torch.no_grad():
                    mu = bn.running_mean
                    var = bn.running_var
                    gamma = bn.weight
                    beta = bn.bias
                    eps = bn.eps
                    w = conv.weight
                    b = conv.bias if conv.bias is not None else torch.zeros_like(mu)
                    
                    denom = torch.rsqrt(var + eps)
                    scale = gamma * denom
                    scale_w = scale.view(-1, 1, 1, 1)
                    
                    conv.weight.data.mul_(scale_w)
                    conv.bias = nn.Parameter((b - mu) * scale + beta)
                m = nn.Identity()
        elif isinstance(m, nn.Sequential) or isinstance(m, ResidualBlock):
            fuse_bn_sequential(m)
    return block

def float_to_hex(value, integer_bits=16, fraction_bits=16):
    """Converts float to Q16.16 32-bit Hex String."""
    scale = 1 << fraction_bits
    int_val = int(value * scale)
    max_val = (1 << (integer_bits + fraction_bits - 1)) - 1
    min_val = -(1 << (integer_bits + fraction_bits - 1))
    
    if int_val > max_val: int_val = max_val
    if int_val < min_val: int_val = min_val
    
    if int_val < 0:
        int_val = (1 << 32) + int_val
    return f"{int_val:08X}"

def save_tensor_to_hex(tensor, filename):
    data = tensor.detach().cpu().numpy().flatten()
    with open(filename, 'w') as f:
        for val in data:
            f.write(float_to_hex(val) + '\n')
    print(f"Saved {len(data)} entries to {filename}")

def debug_hook(module, input, output):
    """Prints sum of layer output for debugging."""
    if isinstance(output, torch.Tensor):
        val = output.detach().sum().item()
        print(f"[DEBUG PyTorch] Layer {module.__class__.__name__}: Sum = {val:.4f}")

# ==========================================
# 3. MAIN SCRIPT
# ==========================================

if __name__ == "__main__":
    set_seeds()
    
    # --- A. Load Model ---
    config = Config()
    model = Generator(config)
    
    # Load Weights (Adjust filename if needed)
    chk_path = "generator_epoch_9500.pt" 
    if os.path.exists(chk_path):
        print(f"Loading weights from {chk_path}...")
        model.load_state_dict(torch.load(chk_path, map_location='cpu'))
    else:
        print("WARNING: Checkpoint not found. Using random weights!")
    
    model.eval()

    print("Fusing Batch Norm...")
    fuse_bn_sequential(model)
    
    # --- B. Register Debug Hooks ---
    print("--- Registering Debug Hooks ---")
    # Hook Neck
    model.neck[0].register_forward_hook(debug_hook) # Conv
    model.neck[1].register_forward_hook(debug_hook) # PReLU
    
    # Hook Stem (Residual Blocks)
    for i in range(len(model.stem)):
        model.stem[i].conv1.register_forward_hook(debug_hook)
        model.stem[i].conv2.register_forward_hook(debug_hook)
        # Hook the block output (Post-Addition)
        model.stem[i].register_forward_hook(debug_hook)

    # --- C. Generate Deterministic Input (Gradient) ---
    print("Generating Gradient Input Pattern...")
    input_dummy = torch.zeros(1, 3, 8, 8)
    for c in range(3):
        for y in range(8):
            for x in range(8):
                # Gradient from -1.0 to 1.0 based on position
                # This makes it easy to spot if rows/cols are flipped
                val = ((x + y) / 16.0) * 2.0 - 1.0
                input_dummy[0, c, y, x] = val

    # --- D. Run Inference & Save Golden Data ---
    with torch.no_grad():
        output_dummy = model(input_dummy)

    if not os.path.exists("mem_export"):
        os.makedirs("mem_export")

    save_tensor_to_hex(input_dummy, "mem_export/tb_input_image.hex")
    save_tensor_to_hex(output_dummy, "mem_export/tb_golden_output.hex")

    # --- E. Export Weights ---
    print("Exporting Weights to Hex...")
    for name, param in model.named_parameters():
        clean_name = name.replace(".", "_")
        filename = f"mem_export/{clean_name}.hex"
        save_tensor_to_hex(param, filename)

    print("Done! Files saved in 'mem_export/' folder.")