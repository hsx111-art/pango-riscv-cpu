param(
    [string]$ModelSimHome = $(if ($env:MODELSIM_HOME) { $env:MODELSIM_HOME } else { 'A:\modletech64_2020.4' }),
    [string]$ToolchainBin = $(if ($env:RISCV_TOOLCHAIN_BIN) { $env:RISCV_TOOLCHAIN_BIN } else { 'A:\Vivado\2025.2\gnu\riscv\nt\bin' }),
    [string]$BuildRoot = 'C:\ultraembedded-riscv-competition-modelsim'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$vlog = Join-Path $ModelSimHome 'win64\vlog.exe'
$vsim = Join-Path $ModelSimHome 'win64\vsim.exe'
$modelsimIni = Join-Path $ModelSimHome 'modelsim.ini'
$buildScript = Join-Path $repo 'verification\competition\build_competition_smoke.ps1'
$filelist = Join-Path $repo 'verification\modelsim\filelist.f'
$peripherals = Join-Path $repo 'competition\competition_peripherals.v'
$top = Join-Path $repo 'competition\competition_top.v'
$testbench = Join-Path $repo 'verification\modelsim\tb_competition.v'

foreach ($path in @($vlog, $vsim, $modelsimIni, $buildScript, $filelist, $peripherals, $top, $testbench)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required competition path does not exist: $path"
    }
}

if (Test-Path -LiteralPath $BuildRoot) {
    Remove-Item -LiteralPath $BuildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
$work = Join-Path $BuildRoot 'work'
$memh = Join-Path $BuildRoot 'competition.memh'
$doFile = Join-Path $BuildRoot 'competition_run.do'
New-Item -ItemType Directory -Force -Path $work | Out-Null

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript -ToolchainBin $ToolchainBin -OutputRoot (Join-Path $repo '.build\competition')
if ($LASTEXITCODE -ne 0) {
    throw "Competition software build failed with exit code $LASTEXITCODE"
}
Copy-Item -LiteralPath (Join-Path $repo '.build\competition\competition.memh') -Destination $memh -Force

& (Join-Path $ModelSimHome 'win64\vlib.exe') $work
if ($LASTEXITCODE -ne 0) {
    throw "vlib failed with exit code $LASTEXITCODE"
}

$compileOutput = (& $vlog '-work' $work '+define+verilog_sim' '-lint' '-f' $filelist $peripherals $top $testbench 2>&1 | Out-String)
$compileOutput | Write-Host
if ($LASTEXITCODE -ne 0 -or $compileOutput -match 'Errors:\s*[1-9]') {
    throw 'Competition RTL compilation failed.'
}

$doLines = @(
    'run -all',
    'set pass_state [examine /tb_competition/pass_seen]',
    'if {$pass_state eq "1''h1"} {',
    '    echo COMPETITION_TCM_PASS_MARKER',
    '} else {',
    '    echo COMPETITION_TCM_FAIL_MARKER',
    '}',
    'echo COMPETITION_CYCLES=[examine /tb_competition/cycle_count]',
    'quit -f'
)
[System.IO.File]::WriteAllLines($doFile, $doLines, [System.Text.UTF8Encoding]::new($false))

Push-Location $BuildRoot
try {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& $vsim '-batch' '-modelsimini' $modelsimIni '-onfinish' 'stop' '-voptargs=+acc' '-L' '.\work' 'tb_competition' '-do' '.\competition_run.do' 2>&1 | Out-String)
        $simExit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}
finally {
    Pop-Location
}
$output | Write-Host

if ($simExit -ne 0 -or
    $output -notmatch 'COMPETITION_TCM_PASS_MARKER' -or
    $output -match 'COMPETITION_TCM_FAIL_MARKER' -or
    $output -match 'COMPETITION_FAIL') {
    throw "Competition ModelSim smoke failed with exit code $simExit"
}

Write-Host 'COMPETITION_MODELSIM_PASS'
