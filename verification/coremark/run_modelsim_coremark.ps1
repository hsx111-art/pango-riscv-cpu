param(
    [string]$ModelSimHome = $(if ($env:MODELSIM_HOME) { $env:MODELSIM_HOME } else { 'A:\modletech64_2020.4' }),
    [string]$WslDistribution = 'Ubuntu-A',
    [int]$Iterations = 1,
    [ValidateSet('performance', 'validation', 'profile')]
    [string]$RunType = 'validation',
    [int]$ClockHz = 1000000,
    [int]$MaxCycles = 2000000,
    [int]$EnableBranchPredictor = 0,
    [int]$EnableBranchPredictorRedirect = 0
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$vlog = Join-Path $ModelSimHome 'win64\vlog.exe'
$vlib = Join-Path $ModelSimHome 'win64\vlib.exe'
$vsim = Join-Path $ModelSimHome 'win64\vsim.exe'
$modelsimIni = Join-Path $ModelSimHome 'modelsim.ini'
$converter = Join-Path $repo 'verification\modelsim\elf_to_memh.py'
$filelist = Join-Path $repo 'verification\modelsim\filelist.f'
$testbench = Join-Path $repo 'verification\modelsim\tb_tcm_regression.v'

foreach ($path in @($vlog, $vlib, $vsim, $modelsimIni, $converter, $filelist, $testbench)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required CoreMark ModelSim path does not exist: $path"
    }
}
if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    throw 'Python 3 (py.exe) is required for ELF-to-memory conversion.'
}

$buildRoot = 'C:\ultraembedded-riscv-modelsim\coremark'
$memh = Join-Path $buildRoot 'coremark.memh'
$simRoot = Join-Path $buildRoot 'sim'
if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $simRoot | Out-Null

function Convert-ToWslPath([string]$WindowsPath) {
    $full = (Resolve-Path -LiteralPath $WindowsPath).Path
    $drive = $full.Substring(0, 1).ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

$wslRepo = Convert-ToWslPath $repo
$wslCommand = "env -i HOME=/home/shixin PATH=/home/shixin/.local/riscv-tools/usr/bin:/usr/bin:/bin bash -lc 'cd $wslRepo; make -C verification/coremark clean; make -C verification/coremark ITERATIONS=$Iterations RUN_TYPE=$RunType CLOCK_HZ=$ClockHz'"
Push-Location C:\
try {
    & wsl.exe -d $WslDistribution -- bash -lc $wslCommand
    if ($LASTEXITCODE -ne 0) {
        throw "WSL CoreMark build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$elf = Join-Path $repo '.build\coremark\coremark.elf'
if (-not (Test-Path -LiteralPath $elf)) {
    throw "CoreMark ELF was not produced: $elf"
}
& py.exe -3 $converter --elf $elf --output $memh
if ($LASTEXITCODE -ne 0) {
    throw "CoreMark ELF conversion failed with exit code $LASTEXITCODE"
}

Push-Location $simRoot
try {
    & $vlib work
    if ($LASTEXITCODE -ne 0) { throw "vlib failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

Push-Location $repo
try {
    & $vlog '-work' (Join-Path $simRoot 'work') '+define+verilog_sim' '-lint' '-f' $filelist $testbench
    if ($LASTEXITCODE -ne 0) { throw "vlog failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

$simArgs = @(
    '-batch',
    '-modelsimini', $modelsimIni,
    'work.tb_tcm_regression',
    "-gENABLE_BRANCH_PREDICTOR=$EnableBranchPredictor",
    "-gENABLE_BRANCH_PREDICTOR_REDIRECT=$EnableBranchPredictorRedirect",
    "+MEMH=$(($memh.Replace('\', '/')))",
    '+TESTNAME=coremark',
    "+MAX_CYCLES=$MaxCycles",
    '-do', 'run -all; quit -f'
)
Push-Location $simRoot
try {
    $output = (& $vsim @simArgs 2>&1 | Out-String)
    $rc = $LASTEXITCODE
}
finally {
    Pop-Location
}
$output | Write-Host

if ($rc -ne 0 -or
    $output -notmatch 'MODELSIM_TEST_PASS' -or
    $output -notmatch 'MODELSIM_TEST_COMPLETE' -or
    $output -match 'MODELSIM_TEST_FAIL' -or
    $output -match 'ERROR! list crc' -or
    $output -match 'ERROR! matrix crc' -or
    $output -match 'ERROR! state crc' -or
    $output -notmatch 'COREMARK_METRICS' -or
    $output -notmatch 'cpi_x1000') {
    throw "CoreMark ModelSim smoke failed with exit code $rc"
}

Write-Host "COREMARK_MODELSIM_SMOKE_PASS ITERATIONS=$Iterations RUN_TYPE=$RunType"
