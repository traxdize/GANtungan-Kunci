import torch
import torch.nn as nn
import numpy as np
import os


# Model Definition
# Is exactly from the kaggle model for generator including residual, upsampling, etc.

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

# Di kaggle, this is conf_dict and is called by config = OmegaConf.create(conf_dict)
class Config:
    def __init__(self):
        self.n_filters = 64
        self.n_layers = 8


# BN FOLDING -> Supaya jimmy gak marah, BatchNorm2d difuse secara rekursif
# Formula:  W_new = W_old * (gamma / sqrt(var + eps))
#           B_new = (B_old - mu) * (gamma / sqrt(var + eps)) + beta

def fuse_bn_sequential(block):
    stack = []
    for m in block.children():
        if isinstance(m, nn.Conv2d):
            stack.append(m)
        elif isinstance(m, nn.BatchNorm2d):
            if stack and isinstance(stack[-1], nn.Conv2d):
                conv = stack.pop()
                bn = m
                
                # Fuse Logic
                with torch.no_grad():
                    # BN parameters
                    mu = bn.running_mean
                    var = bn.running_var
                    gamma = bn.weight
                    beta = bn.bias
                    eps = bn.eps
                    
                    # Conv parameters
                    w = conv.weight
                    if conv.bias is None:
                        b = torch.zeros_like(mu)
                    else:
                        b = conv.bias

                    # Math: W_new = W_old * (gamma / sqrt(var + eps))
                    #       B_new = (B_old - mu) * (gamma / sqrt(var + eps)) + beta
                    denom = torch.rsqrt(var + eps)
                    scale = gamma * denom
                    
                    # Reshape scale for broadcasting (out_channels, 1, 1, 1)
                    scale_w = scale.view(-1, 1, 1, 1)
                    
                    conv.weight.data.mul_(scale_w)
                    conv.bias = nn.Parameter((b - mu) * scale + beta)
                    
                # Replace BN with Identity (no-op)
                m = nn.Identity()
        elif isinstance(m, nn.Sequential) or isinstance(m, ResidualBlock):
            fuse_bn_sequential(m)
            
    return block

# float to fixed point (Q16.16) in HEX
def float_to_hex(value, integer_bits=16, fraction_bits=16):
    """
    Converts a float to Q16.16 (32-bit) Hex String.
    Example: 1.0 -> 00010000, -1.0 -> FFFF0000
    """
    scale = 1 << fraction_bits
    int_val = int(value * scale)
    
    # Handle saturation/clipping for 32-bit signed
    max_val = (1 << (integer_bits + fraction_bits - 1)) - 1
    min_val = -(1 << (integer_bits + fraction_bits - 1))
    
    if int_val > max_val: int_val = max_val
    if int_val < min_val: int_val = min_val
    
    # Handle 2's complement
    if int_val < 0:
        int_val = (1 << 32) + int_val
        
    return f"{int_val:08X}"


def save_tensor_to_hex(tensor, filename):
    """Flatten tensor and save to hex file line by line."""
    data = tensor.detach().cpu().numpy().flatten()
    with open(filename, 'w') as f:
        for val in data:
            f.write(float_to_hex(val) + '\n')
    print(f"Saved {len(data)} entries to {filename}")


def debug_hook(module, input, output):
    # Calculate simple sum of all values in the output tensor
    if isinstance(output, torch.Tensor):
        val = output.detach().sum().item()
        print(f"[DEBUG PyTorch] Layer {module.__class__.__name__}: Sum = {val:.4f}")


if __name__ == "__main__":
    # --- A. Load Model ---
    config = Config()
    model = Generator(config)
    
    # LOAD YOUR WEIGHTS HERE
    model.load_state_dict(torch.load("generator_epoch_9500.pt", map_location='cpu')) 
    model.eval()

    print("Model loaded. Fusing Batch Norm...")
    
    # --- B. Fuse Batch Norm ---
    # We apply fusion to the specific parts of SRGAN that have BN
    fuse_bn_sequential(model)
    
    # --- C. Generate Golden Data ---
    print("Generating Golden Model Data...")
    
    # Create dummy input: 1 image, 3 channels, 8x8 size (small for testing)
    input_dummy = torch.zeros(1, 3, 8, 8)
    for c in range(3):
        for y in range(8):
            for x in range(8):
                # Normalize 0..8 to -1..1
                val = ((x + y) / 16.0) * 2.0 - 1.0
                input_dummy[0, c, y, x] = val
    
    # Register hooks to print sums
    print("--- Registering Debug Hooks ---")
    for name, layer in model.named_modules():
        # Only hook "leaf" layers (Conv, PReLU, etc.)
        if len(list(layer.children())) == 0: 
            layer.register_forward_hook(debug_hook)

    # Now run inference
    with torch.no_grad():
        output_dummy = model(input_dummy)

    # Create output directory
    if not os.path.exists("mem_export"):
        os.makedirs("mem_export")

    # Save Input/Output for Testbench
    save_tensor_to_hex(input_dummy, "mem_export/tb_input_image.hex")
    save_tensor_to_hex(output_dummy, "mem_export/tb_golden_output.hex")

    # --- D. Export Weights ---
    print("Exporting Weights to Hex...")
    
    # Strategy: Iterate through named parameters and save them.
    # Note: Hardware implementation will likely need specific files for specific layers.
    # This loop dumps them generally. for strict hardware mapping, you might
    # want to manually select layers (e.g., model.neck[0].weight).
    
    for name, param in model.named_parameters():
        # Clean name for filename (e.g., neck.0.weight -> neck_0_weight.hex)
        clean_name = name.replace(".", "_")
        filename = f"mem_export/{clean_name}.hex"
        
        # PReLU weights are named 'weight' usually, but shape is [channels]
        # Conv weights are [out, in, k, k]
        
        save_tensor_to_hex(param, filename)

    print("Done! Files saved in 'mem_export/' folder.")