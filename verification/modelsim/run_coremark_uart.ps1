param(
    [string]$ModelSimHome = $(if ($env:MODELSIM_HOME) { $env:MODELSIM_HOME } else { 'A:\modletech64_2020.4' }),
    [string]$WslDistribution = 'Ubuntu-A',
    [int]$Iterations = 1,
    [ValidateSet('performance', 'validation', 'profile')]
    [string]$RunType = 'validation',
    [int]$ClockHz = 1000000,
    [int]$MaxCycles = 2000000,
    [string]$BuildRoot = 'C:\ultraembedded-riscv-coremark-uart-modelsim'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$vlog = Join-Path $ModelSimHome 'win64\vlog.exe'
$vlib = Join-Path $ModelSimHome 'win64\vlib.exe'
$vsim = Join-Path $ModelSimHome 'win64\vsim.exe'
$modelsimIni = Join-Path $ModelSimHome 'modelsim.ini'
$converter = Join-Path $repo 'verification\modelsim\elf_to_memh.py'
$filelist = Join-Path $repo 'verification\modelsim\filelist.f'
$peripherals = Join-Path $repo 'competition\competition_peripherals.v'
$top = Join-Path $repo 'competition\competition_top.v'
$testbench = Join-Path $repo 'verification\modelsim\tb_competition.v'

foreach ($path in @($vlog, $vlib, $vsim, $modelsimIni, $converter, $filelist, $peripherals, $top, $testbench)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required CoreMark UART path does not exist: $path"
    }
}
if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    throw 'Python 3 (py.exe) is required for ELF-to-memory conversion.'
}

function Convert-ToWslPath([string]$WindowsPath) {
    $full = if (Test-Path -LiteralPath $WindowsPath) {
        (Resolve-Path -LiteralPath $WindowsPath).Path
    }
    else {
        [System.IO.Path]::GetFullPath($WindowsPath)
    }
    $drive = $full.Substring(0, 1).ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

if (Test-Path -LiteralPath $BuildRoot) {
    Remove-Item -LiteralPath $BuildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
$work = Join-Path $BuildRoot 'work'
$memh = Join-Path $BuildRoot 'competition.memh'
$doFile = Join-Path $BuildRoot 'coremark_uart_run.do'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$wslRepo = Convert-ToWslPath $repo
$wslOut = Convert-ToWslPath (Join-Path $repo '.build\coremark-uart-modelsim')
$wslCommand = "env -i HOME=/home/shixin PATH=/home/shixin/.local/riscv-tools/usr/bin:/usr/bin:/bin bash -lc 'cd $wslRepo; make -C verification/coremark clean OUT=$wslOut; make -C verification/coremark OUT=$wslOut ITERATIONS=$Iterations RUN_TYPE=$RunType CLOCK_HZ=$ClockHz OUTPUT_DEVICE=competition-uart'"
Push-Location C:\
try {
    & wsl.exe -d $WslDistribution -- bash -lc $wslCommand
    if ($LASTEXITCODE -ne 0) {
        throw "CoreMark UART build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$elf = Join-Path $repo '.build\coremark-uart-modelsim\coremark.elf'
if (-not (Test-Path -LiteralPath $elf)) {
    throw "CoreMark UART ELF was not produced: $elf"
}
& py.exe -3 $converter --elf $elf --output $memh --ram-words 16384
if ($LASTEXITCODE -ne 0) {
    throw "CoreMark UART ELF conversion failed with exit code $LASTEXITCODE"
}

Push-Location $BuildRoot
try {
    & $vlib work
    if ($LASTEXITCODE -ne 0) { throw "vlib failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

Push-Location $repo
try {
    $compileOutput = (& $vlog '-work' $work '+define+verilog_sim' '-lint' '-f' $filelist $peripherals $top $testbench 2>&1 | Out-String)
    $compileOutput | Write-Host
    if ($LASTEXITCODE -ne 0 -or $compileOutput -match 'Errors:\s*[1-9]') {
        throw 'CoreMark UART RTL compilation failed.'
    }
}
finally {
    Pop-Location
}

$doLines = @(
    'run -all',
    'set pass_state [examine /tb_competition/pass_seen]',
    'if {$pass_state eq "1''h1"} {',
    '    echo COREMARK_UART_PASS_MARKER',
    '} else {',
    '    echo COREMARK_UART_FAIL_MARKER',
    '}',
    'echo COREMARK_CYCLES=[examine /tb_competition/cycle_count]',
    'quit -f'
)
[System.IO.File]::WriteAllLines($doFile, $doLines, [System.Text.UTF8Encoding]::new($false))

Push-Location $BuildRoot
try {
    $output = (& $vsim '-batch' '-modelsimini' $modelsimIni '-onfinish' 'stop' '-voptargs=+acc' '-L' '.\work' 'tb_competition' '+COREMARK_MODE' "+MAX_CYCLES=$MaxCycles" '-do' '.\coremark_uart_run.do' 2>&1 | Out-String)
    $simExit = $LASTEXITCODE
}
finally {
    Pop-Location
}
$output | Write-Host

if ($simExit -ne 0 -or
    $output -notmatch 'COREMARK_UART_PASS_MARKER' -or
    $output -match 'COREMARK_UART_FAIL_MARKER' -or
    $output -notmatch 'seedcrc\s+: 0x18f2' -or
    $output -notmatch '\[0\]crclist\s+: 0xe3c1' -or
    $output -notmatch '\[0\]crcmatrix\s+: 0x0747' -or
    $output -notmatch '\[0\]crcstate\s+: 0x8d84' -or
    $output -notmatch '\[0\]crcfinal\s+: 0xe3c1' -or
    $output -match 'ERROR! list crc' -or
    $output -match 'ERROR! matrix crc' -or
    $output -match 'ERROR! state crc' -or
    $output -match 'PORT_TYPE_ERROR') {
    throw "CoreMark UART ModelSim smoke failed with exit code $simExit"
}

Write-Host "COREMARK_UART_MODELSIM_PASS ITERATIONS=$Iterations RUN_TYPE=$RunType VALIDITY=short-run"
