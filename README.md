# UAS EL4013 - Perancangan Sistem VLSI
## Simple GAN
K2_4 GANtungan Kunci

Files used:
- gan3x3.v
- memory.v
- pe_neuron.v
- sigmoid_lut.v
- tanh_lut.v

Testbenches:
- tb_gan3x3.v
- tb_sigmoid_lut.v
- tb_tanh_lut.v

Python Scripts:
- inference.py
- lut_generator.py
- weight_bias_generator.py

How to run (windows based):
```
./run.ps1
```

Default parameters are Q8.24 and using cross.mat for weights. To change parameters of fixed point, change the variables in the powershell script file.

```ps
# Fixed Point Format (e.g., 24 for Q8.24, 16 for Q16.16)
$FracBits = 28

# Input MAT File for Weights/Biases
$MatFile = "generator/cross.mat"
# $MatFile = "generator/cross2.mat"
# $MatFile = "generator/edge.mat"
# $MatFile = "generator/line.mat"
# $MatFile = "generator/triangle.mat"
```
> comment the current .mat and uncomment the used .mat