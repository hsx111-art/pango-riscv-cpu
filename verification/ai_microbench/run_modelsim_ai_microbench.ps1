param(
    [string]$ModelSimHome = $(if ($env:MODELSIM_HOME) { $env:MODELSIM_HOME } else { 'A:\modletech64_2020.4' }),
    [string]$WslDistribution = 'Ubuntu-A',
    [int]$AiRepeat = 16,
    [int]$MaxCycles = 2000000
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
        throw "Required AI ModelSim path does not exist: $path"
    }
}
if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    throw 'Python 3 (py.exe) is required for ELF-to-memory conversion.'
}

$buildRoot = 'C:\ultraembedded-riscv-modelsim\ai-microbench'
$outDir = Join-Path $repo '.build\ai_microbench'
$memhRoot = Join-Path $buildRoot 'memh'
$simRoot = Join-Path $buildRoot 'sim'
$logRoot = Join-Path $buildRoot 'logs'

if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $memhRoot, $simRoot, $logRoot | Out-Null

function Convert-ToWslPath([string]$WindowsPath) {
    $full = (Resolve-Path -LiteralPath $WindowsPath).Path
    $drive = $full.Substring(0, 1).ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

$wslRepo = Convert-ToWslPath $repo
$wslCommand = "env -i HOME=/home/shixin PATH=/home/shixin/.local/riscv-tools/usr/bin:/usr/bin:/bin bash -lc 'cd $wslRepo; make -C verification/ai_microbench clean; make -C verification/ai_microbench AI_REPEAT=$AiRepeat'"
Push-Location C:\
try {
    & wsl.exe -d $WslDistribution -- bash -lc $wslCommand
    if ($LASTEXITCODE -ne 0) {
        throw "WSL AI microbench build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
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

foreach ($workload in @('dot_i8', 'gemm_i8', 'conv_i8', 'relu_i8')) {
    $elf = Join-Path $outDir "$workload.elf"
    if (-not (Test-Path -LiteralPath $elf)) {
        throw "Missing AI microbench ELF: $elf"
    }
    $memh = Join-Path $memhRoot "$workload.memh"
    & py.exe -3 $converter --elf $elf --output $memh
    if ($LASTEXITCODE -ne 0) { throw "ELF conversion failed for $workload" }

    Write-Host "MODELSIM_AI_RUN $workload"
    $simArgs = @(
        '-batch',
        '-modelsimini', $modelsimIni,
        'work.tb_tcm_regression',
        "+MEMH=$(($memh.Replace('\', '/')))",
        "+TESTNAME=ai/$workload",
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
    $log = Join-Path $logRoot "$workload.log"
    $output | Tee-Object -FilePath $log | Write-Host

    if ($rc -ne 0 -or
        $output -notmatch "AI_METRICS workload=$workload" -or
        $output -notmatch 'MODELSIM_PROFILE' -or
        $output -notmatch 'MODELSIM_TEST_PASS' -or
        $output -notmatch 'MODELSIM_TEST_COMPLETE' -or
        $output -match 'MODELSIM_TEST_FAIL') {
        throw "ModelSim AI microbench failed for $workload with exit code $rc"
    }
    Write-Host "MODELSIM_AI_PASS $workload"
}

Write-Host "MODELSIM_AI_REGRESSION_PASS AI_REPEAT=$AiRepeat"
