import torch
import torch.nn as nn
import numpy as np
import os

class Config:
    def __init__(self):
        self.n_filters = 64
        self.n_layers = 8 

def set_seeds():
    torch.manual_seed(42)
    np.random.seed(42)

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
        x = self.neck(x)
        residual = x
        x = self.stem(x)
        x = self.bottleneck(x) + residual
        x = self.upsampling(x)
        return self.head(x)

def fuse_conv_and_bn(conv, bn):
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
        fused_w = w * scale_w
        fused_b = (b - mu) * scale + beta
    return nn.Parameter(fused_w), nn.Parameter(fused_b)

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

if __name__ == "__main__":
    set_seeds()
    config = Config()
    model = Generator(config)

    chk_path = "generator_epoch_9500.pt"
    if os.path.exists(chk_path):
        print(f"Loading {chk_path}...")
        try:
            state_dict = torch.load(chk_path, map_location='cpu')
            model.load_state_dict(state_dict)
            print("Weights loaded.")
        except Exception as e:
            print(f"Error loading: {e}. Using RANDOM weights.")
    else:
        print("Checkpoint not found. Using RANDOM weights.")

    model.eval()

    print("Fusing Batch Norm layers...")
    for module in model.modules():
        if isinstance(module, ResidualBlock):
            w, b = fuse_conv_and_bn(module.conv1, module.bn1)
            module.conv1.weight = w; module.conv1.bias = b; module.bn1 = nn.Identity()
            w, b = fuse_conv_and_bn(module.conv2, module.bn2)
            module.conv2.weight = w; module.conv2.bias = b; module.bn2 = nn.Identity()
    
    if isinstance(model.bottleneck[1], nn.BatchNorm2d):
         w, b = fuse_conv_and_bn(model.bottleneck[0], model.bottleneck[1])
         model.bottleneck[0].weight = w
         model.bottleneck[0].bias = b
         model.bottleneck[1] = nn.Identity()

    print("Generating Gradient Input...")
    input_dummy = torch.zeros(1, 3, 32, 32)
    for c in range(3):
        for y in range(32):
            for x in range(32):
                input_dummy[0, c, y, x] = ((x + y) / 64.0) * 2.0 - 1.0

    print("Exporting 'all_weights_gen.hex'...")
    with open("all_weights_gen.hex", "w") as f:
        
        def write_layer_block(conv, prelu=None):
            w = conv.weight.data[0, 0, :, :].flatten()
            for val in w: f.write(float_to_hex(val.item()) + "\n")
            
            b = conv.bias.data[0]
            f.write(float_to_hex(b.item()) + "\n")
            
            if prelu is not None:
                s = prelu.weight.data[0]
                f.write(float_to_hex(s.item()) + "\n")
            else:
                f.write(float_to_hex(1.0) + "\n")

            for _ in range(5): f.write("00000000\n")

        write_layer_block(model.neck[0], model.neck[1])

        for i in range(len(model.stem)):
            write_layer_block(model.stem[i].conv1, model.stem[i].relu1)
            write_layer_block(model.stem[i].conv2, None)
            
        write_layer_block(model.bottleneck[0], None)
        
        for i in range(len(model.upsampling)):
            write_layer_block(model.upsampling[i].conv, model.upsampling[i].relu)
            
        write_layer_block(model.head[0], None)

    print("Exporting Verification Data...")
    with torch.no_grad():
        output_dummy = model(input_dummy)

    save_tensor_to_hex(input_dummy, "tb_input_gen.hex")
    save_tensor_to_hex(output_dummy, "tb_golden_gen.hex")

    print(f"Generator Export Complete.")