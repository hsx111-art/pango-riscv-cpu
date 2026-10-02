param(
    [string]$ModelSimHome = $(if ($env:MODELSIM_HOME) { $env:MODELSIM_HOME } else { 'A:\modletech64_2020.4' }),
    [string]$Image = '',
    [int]$EnableBranchPredictor = 0,
    [int]$EnableBranchPredictorRedirect = 0
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$vlog = Join-Path $ModelSimHome 'win64\vlog.exe'
$vlib = Join-Path $ModelSimHome 'win64\vlib.exe'
$vsim = Join-Path $ModelSimHome 'win64\vsim.exe'
$modelsimIni = Join-Path $ModelSimHome 'modelsim.ini'

if ([string]::IsNullOrWhiteSpace($Image)) {
    $Image = Join-Path $repo 'isa_sim\images\basic.elf'
}

foreach ($tool in @($vlog, $vlib, $vsim, $modelsimIni, $Image)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Required ModelSim or image path does not exist: $tool"
    }
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$buildRoot = 'C:\ultraembedded-riscv-modelsim'
$build = Join-Path $buildRoot $timestamp
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
New-Item -ItemType Directory -Force -Path $build | Out-Null
$env:MODEL_TECH = Join-Path $ModelSimHome 'win64'
$env:MTI_HOME = $ModelSimHome
$env:VSCODE_CWD = ''

Write-Host "Repository: $repo"
Write-Host "ModelSim:   $ModelSimHome"
Write-Host "Image:      $Image"
Write-Host "Build dir:  $build"

if (Get-Command py.exe -ErrorAction SilentlyContinue) {
    & py.exe -3 (Join-Path $PSScriptRoot 'elf_to_memh.py') --elf $Image --output (Join-Path $build 'basic.memh')
}
else {
    throw "Python 3 is required for ELF-to-memory conversion; install the minimal python.org Windows distribution or run the converter in WSL."
}
if ($LASTEXITCODE -ne 0) { throw "ELF conversion failed with exit code $LASTEXITCODE" }

Push-Location $build
try {
    & $vlib work
    if ($LASTEXITCODE -ne 0) { throw "vlib failed with exit code $LASTEXITCODE" }

    Pop-Location
    Push-Location $repo
    try {
        & $vlog -work (Join-Path $build 'work') +define+verilog_sim -lint -f (Join-Path $repo 'verification\modelsim\filelist.f') (Join-Path $repo 'verification\modelsim\tb_tcm_basic.v')
        if ($LASTEXITCODE -ne 0) { throw "vlog failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
        Push-Location $build
    }

    $simLog = Join-Path $build 'modelsim.log'
    & $vsim -batch -modelsimini $modelsimIni work.tb_tcm_basic "-gENABLE_BRANCH_PREDICTOR=$EnableBranchPredictor" "-gENABLE_BRANCH_PREDICTOR_REDIRECT=$EnableBranchPredictorRedirect" -do 'run -all; quit -f' 2>&1 | Tee-Object -FilePath $simLog
    $simExit = $LASTEXITCODE
    $simOutput = Get-Content -LiteralPath $simLog -Raw
    $expectedTests = @(
        '1. Initialised data',
        '2. Multiply',
        '3. Divide',
        '4. Shift left',
        '5. Shift right',
        '6. Shift right arithmetic',
        '7. Signed comparision',
        '8. Word access',
        '9. Byte access',
        '10. Comparision'
    )
    if ($simExit -ne 0 -or
        $simOutput -match 'BASELINE_B_FAIL' -or
        $simOutput -notmatch 'BASELINE_B_PASS' -or
        $simOutput -notmatch 'Errors:\s*0,\s*Warnings:\s*0') {
        throw "vsim failed with exit code $simExit"
    }
    foreach ($expected in $expectedTests) {
        if ($simOutput -notmatch [regex]::Escape($expected)) {
            throw "vsim output is missing expected test marker: $expected"
        }
    }
}
finally {
    Pop-Location
}

Write-Host "BASELINE_B_PASS"
