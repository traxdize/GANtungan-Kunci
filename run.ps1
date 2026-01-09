param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

# Start the Verilog testbench in a new PowerShell window so you have a separate console to inspect.
$src = Join-Path $PSScriptRoot 'src'
$cmd = "Set-Location -Path '$src'; iverilog -o gan3x3 .\tb_gan3x3.v; vvp .\gan3x3"
$sim = Start-Process -FilePath powershell -ArgumentList '-NoExit','-Command', $cmd -PassThru

# Run the inference script in the current window (if present)
$inf = $null
if (Test-Path (Join-Path $PSScriptRoot 'generator\inference.py')) {
    try {
        & python "generator/inference.py"
    } finally {
        # When inference exits (normally or via error), stop the simulator window
        if ($sim -and -not $sim.HasExited) {
            Stop-Process -Id $sim.Id -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "generator\inference.py not found. Simulator window remains open." -ForegroundColor Yellow
}