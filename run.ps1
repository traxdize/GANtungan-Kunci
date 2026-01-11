# Configurable Parameters
# Fixed Point Format (e.g., 24 for Q8.24, 16 for Q16.16)
$FracBits = 28

# Input MAT File for Weights/Biases
$MatFile = "generator/cross.mat"
# $MatFile = "generator/cross2.mat"
# $MatFile = "generator/edge.mat"
# $MatFile = "generator/line.mat"
# $MatFile = "generator/triangle.mat"

# 1. Regenerate LUTs and Weights
if (Test-Path "generator\lut_generator.py") {
    Write-Host "Regenerating LUTs ($FracBits bits)..." -ForegroundColor Cyan
    & python "generator/lut_generator.py" --frac_bits $FracBits
}

if (Test-Path "generator\weight_bias_generator.py") {
    Write-Host "Regenerating Weights from $MatFile ($FracBits bits)..." -ForegroundColor Cyan
    & python "generator/weight_bias_generator.py" $MatFile --frac_bits $FracBits
}

# 2. Run Verilog Simulation
$src = Join-Path $PSScriptRoot 'src'
$cmd = "Set-Location -Path '$src'; iverilog -P tb_gan3x3.FRAC_WIDTH=$FracBits -o gan3x3 .\tb_gan3x3.v; vvp .\gan3x3"
$sim = Start-Process -FilePath powershell -ArgumentList '-NoExit','-Command', $cmd -PassThru

# 3. Run Python Verification
if (Test-Path (Join-Path $PSScriptRoot 'generator\inference.py')) {
    try {
        Write-Host "Running Python Verification..." -ForegroundColor Cyan
        & python "generator/inference.py" --frac_bits $FracBits
    } finally {
        if ($sim -and -not $sim.HasExited) {
            Stop-Process -Id $sim.Id -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "generator\inference.py not found." -ForegroundColor Yellow
}