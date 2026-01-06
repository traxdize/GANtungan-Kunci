import torch
import torch.nn as nn
import numpy as np
import os

# ==========================================
# CONFIGURATION
# ==========================================
class Config:
    def __init__(self):
        self.n_filters = 64

def set_seeds():
    torch.manual_seed(42)
    np.random.seed(42)

# ==========================================
# MODEL
# ==========================================
class SimpleBlock(nn.Module):
    def __init__(self, in_channels, out_channels, stride):
        super().__init__()
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
            SimpleBlock(config.n_filters, config.n_filters, stride=2),
            SimpleBlock(config.n_filters, config.n_filters * 2, stride=1),
            SimpleBlock(config.n_filters * 2, config.n_filters * 2, stride=2),
            SimpleBlock(config.n_filters * 2, config.n_filters * 4, stride=1),
            SimpleBlock(config.n_filters * 4, config.n_filters * 4, stride=2),
            SimpleBlock(config.n_filters * 4, config.n_filters * 8, stride=1),
            SimpleBlock(config.n_filters * 8, config.n_filters * 8, stride=2),
            nn.Conv2d(config.n_filters * 8, 1, 1, 1, 0)
        ]
        self.stem = nn.Sequential(*layers)

    def forward(self, x):
        x = self.neck(x)
        x = self.stem(x)
        return torch.sigmoid(x)

# ==========================================
# UTILS
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

def fuse_bn_simpleblock(module):
    with torch.no_grad():
        conv = module.conv
        bn = module.bn
        mu, var, gamma, beta, eps = bn.running_mean, bn.running_var, bn.weight, bn.bias, bn.eps
        w = conv.weight
        b = conv.bias if conv.bias is not None else torch.zeros_like(mu)
        denom = torch.rsqrt(var + eps)
        scale = gamma * denom
        scale_w = scale.view(-1, 1, 1, 1)
        conv.weight.data.mul_(scale_w)
        conv.bias = nn.Parameter((b - mu) * scale + beta)
    module.bn = nn.Identity()

# ==========================================
# MAIN
# ==========================================
if __name__ == "__main__":
    set_seeds()
    config = Config()
    model = Discriminator(config)
    
    chk_path = "discriminator_epoch_9500.pt"
    if os.path.exists(chk_path):
        print(f"Loading {chk_path}...")
        try:
            model.load_state_dict(torch.load(chk_path, map_location='cpu'))
            print("Weights loaded.")
        except Exception as e:
            print(f"Error loading: {e}. Using RANDOM weights.")
    else:
        print("Checkpoint not found. Using RANDOM weights.")

    model.eval()

    print("Fusing Batch Norm layers...")
    for module in model.stem:
        if isinstance(module, SimpleBlock):
            fuse_bn_simpleblock(module)

    print("Exporting 'all_weights_disc.hex'...")
    with open("all_weights_disc.hex", "w") as f:
        
        def write_layer_block(conv, act_slope=None):
            # A. Weights
            # Handle 1x1 vs 3x3. Flatten size varies.
            # 1x1 kernel has 1 weight. 3x3 kernel has 9 weights.
            # We ALWAYS write 9 lines for weights to maintain ROM alignment.
            # For 1x1, we write the 1 weight, then 8 zeros.
            
            w_flat = conv.weight.data[0, 0, :, :].flatten()
            num_weights = len(w_flat)
            
            for val in w_flat: 
                f.write(float_to_hex(val.item()) + "\n")
            
            # Pad weights to 9 lines if needed (e.g. for 1x1 conv)
            for _ in range(9 - num_weights):
                f.write("00000000\n")
            
            # B. Bias (1 line)
            b = conv.bias.data[0]
            f.write(float_to_hex(b.item()) + "\n")
            
            # C. Slope (1 line)
            if act_slope is not None:
                f.write(float_to_hex(act_slope) + "\n")
            else:
                f.write(float_to_hex(1.0) + "\n")

            # D. Padding (5 lines) to reach 16 total
            for _ in range(5): 
                f.write("00000000\n")

        # Layer 0: Neck
        write_layer_block(model.neck[0], 0.2)
        
        # Layers 1-7: Stem Blocks
        for i, layer in enumerate(model.stem):
            if isinstance(layer, SimpleBlock):
                write_layer_block(layer.conv, 0.2)
            elif isinstance(layer, nn.Conv2d): # Final Layer
                write_layer_block(layer, 1.0) 

    print("Exporting Verification Data...")
    input_dummy = torch.zeros(1, 3, 32, 32)
    for c in range(3):
        for y in range(32):
            for x in range(32):
                input_dummy[0, c, y, x] = ((x + y) / 64.0) * 2.0 - 1.0

    with torch.no_grad():
        output_dummy = model(input_dummy)

    save_tensor_to_hex(input_dummy, "tb_input_disc.hex")
    save_tensor_to_hex(output_dummy, "tb_golden_disc.hex")

    print("Discriminator Export Complete.")