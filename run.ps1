param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$WeightArgs
)

& python "generator/weight_bias_generator.py" @WeightArgs
& python "generator/lut_generator.py"

# open a new terminal and run the Verilog testbench there
$src = Join-Path $PSScriptRoot 'src'
$cmd = "Set-Location -Path '$src'; iverilog -o gan3x3 .\tb_gan3x3.v; vvp .\gan3x3"
Start-Process -FilePath powershell -ArgumentList '-NoExit','-Command', $cmd

& python "generator/inference.py"