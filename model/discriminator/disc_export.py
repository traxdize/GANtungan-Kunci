import torch
import torch.nn as nn
import numpy as np
import os

# ==========================================
# 1. CONFIGURATION
# ==========================================
class Config:
    def __init__(self):
        self.n_filters = 64

def set_seeds():
    torch.manual_seed(42)
    np.random.seed(42)

# ==========================================
# 2. MODEL DEFINITION
# ==========================================
class SimpleBlock(nn.Module):
    def __init__(self, in_channels, out_channels, stride):
        super().__init__()
        # FIXED: Kernel=3, Stride=stride, Padding=1
        self.conv = nn.Conv2d(in_channels, out_channels, 3, stride, 1, bias=False)
        self.bn = nn.BatchNorm2d(out_channels)
        self.act = nn.LeakyReLU(0.2, inplace=True)

    def forward(self, x):
        return self.act(self.bn(self.conv(x)))

class Discriminator(nn.Module):
    def __init__(self, config):
        super().__init__()
        self.neck = nn.Sequential(
            nn.Conv2d(3, config.n_filters, 3, 1, 1),
            nn.LeakyReLU(0.2, inplace=True),
        )

        layers = [
            SimpleBlock(config.n_filters, config.n_filters, stride=2),      # Block 0
            SimpleBlock(config.n_filters, config.n_filters * 2, stride=1),  # Block 1
            SimpleBlock(config.n_filters * 2, config.n_filters * 2, stride=2),
            SimpleBlock(config.n_filters * 2, config.n_filters * 4, stride=1),
            SimpleBlock(config.n_filters * 4, config.n_filters * 4, stride=2),
            SimpleBlock(config.n_filters * 4, config.n_filters * 8, stride=1),
            SimpleBlock(config.n_filters * 8, config.n_filters * 8, stride=2),
            nn.Conv2d(config.n_filters * 8, 1, 1, 1, 0) # Final 1x1
        ]
        self.stem = nn.Sequential(*layers)

    def forward(self, x):
        x = self.neck(x)
        return self.stem(x)

# ==========================================
# 3. FUSION LOGIC (BN + Conv)
# ==========================================
def fuse_conv_and_bn(conv, bn):
    with torch.no_grad():
        mu = bn.running_mean
        var = bn.running_var
        gamma = bn.weight
        beta = bn.bias
        eps = bn.eps
        w = conv.weight
        if conv.bias is not None:
            b = conv.bias
        else:
            b = torch.zeros_like(mu)
        
        denom = torch.rsqrt(var + eps)
        scale = gamma * denom
        scale_w = scale.view(-1, 1, 1, 1)
        
        fused_w = w * scale_w
        fused_b = (b - mu) * scale + beta
        
    return nn.Parameter(fused_w), nn.Parameter(fused_b)

def fuse_discriminator_blocks(model):
    print("Fusing Batch Norm layers...")
    for name, module in model.named_modules():
        if isinstance(module, SimpleBlock):
            # Calculate fused weights
            fused_w, fused_b = fuse_conv_and_bn(module.conv, module.bn)
            
            # Update Conv
            module.conv.weight = fused_w
            module.conv.bias = fused_b
            
            # Disable BN
            module.bn = nn.Identity()

# ==========================================
# 4. HEX UTILITIES
# ==========================================
def float_to_hex(value):
    scale = 65536
    int_val = int(value * scale)
    if int_val > 2147483647: int_val = 2147483647
    if int_val < -2147483648: int_val = -2147483648
    if int_val < 0: int_val = (1 << 32) + int_val
    return f"{int_val:08X}"

def save_tensor_to_hex(tensor, filename):
    data = tensor.detach().cpu().numpy().flatten()
    with open(filename, 'w') as f:
        for val in data:
            f.write(float_to_hex(val) + '\n')
    print(f"Saved {len(data)} entries to {filename}")

# ==========================================
# 5. MAIN EXECUTION
# ==========================================
if __name__ == "__main__":
    set_seeds()
    config = Config()
    model = Discriminator(config)
    
    # Load Weights
    chk_path = "discriminator_epoch_9500.pt"
    if os.path.exists(chk_path):
        print(f"Loading weights from {chk_path}...")
        model.load_state_dict(torch.load(chk_path, map_location='cpu'))
    else:
        print("WARNING: Checkpoint not found. Using random weights.")

    model.eval()

    # Apply Hardware Optims
    fuse_discriminator_blocks(model)
    
    # Generate Deterministic Input (Gradient)
    print("Generating Gradient Input (32x32)...")
    input_dummy = torch.zeros(1, 3, 32, 32)
    for c in range(3):
        for y in range(32):
            for x in range(32):
                val = ((x + y) / 64.0) * 2.0 - 1.0
                input_dummy[0, c, y, x] = val

    # Run Inference
    print("Running Inference...")
    with torch.no_grad():
        output_dummy = model(input_dummy)

    # Export Data
    if not os.path.exists("mem_export_disc"):
        os.makedirs("mem_export_disc")

    print("Exporting Input and Golden Output...")
    save_tensor_to_hex(input_dummy, "mem_export_disc/tb_input_disc.hex")
    save_tensor_to_hex(output_dummy, "mem_export_disc/tb_golden_disc.hex")

    print("Exporting Layer Weights...")
    for name, param in model.named_parameters():
        clean_name = name.replace(".", "_")
        filename = f"mem_export_disc/{clean_name}.hex"
        save_tensor_to_hex(param, filename)

    print("Done. Files saved in 'mem_export_disc/'")