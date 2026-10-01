param(
    [string]$ModelSimHome = $(if ($env:MODELSIM_HOME) { $env:MODELSIM_HOME } else { 'A:\modletech64_2020.4' }),
    [string]$WslDistribution = 'Ubuntu-A',
    [string]$TestFilter = '',
    [int]$MaxCycles = 1000000,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$vlog = Join-Path $ModelSimHome 'win64\vlog.exe'
$vlib = Join-Path $ModelSimHome 'win64\vlib.exe'
$vsim = Join-Path $ModelSimHome 'win64\vsim.exe'
$modelsimIni = Join-Path $ModelSimHome 'modelsim.ini'
$converter = Join-Path $PSScriptRoot 'elf_to_memh.py'
$filelist = Join-Path $repo 'verification\modelsim\filelist.f'
$testbench = Join-Path $repo 'verification\modelsim\tb_tcm_regression.v'
$manifest = Join-Path $repo 'verification\riscv_tests\manifest.tsv'

foreach ($path in @($vlog, $vlib, $vsim, $modelsimIni, $converter, $filelist, $testbench, $manifest)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required regression path does not exist: $path"
    }
}
if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    throw 'Python 3 (py.exe) is required for ELF-to-memory conversion.'
}

$buildRoot = 'C:\ultraembedded-riscv-modelsim\riscv-regression'
$imageRoot = Join-Path $buildRoot 'images'
$memhRoot = Join-Path $buildRoot 'memh'
$simRoot = Join-Path $buildRoot 'sim'
$logRoot = Join-Path $buildRoot 'logs'

function Convert-ToWslPath([string]$WindowsPath) {
    $full = (Resolve-Path -LiteralPath $WindowsPath).Path
    $drive = $full.Substring(0, 1).ToLowerInvariant()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

if (-not $SkipBuild) {
    if (Test-Path -LiteralPath $buildRoot) {
        Remove-Item -LiteralPath $buildRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $imageRoot, $memhRoot, $simRoot, $logRoot | Out-Null

    $wslRepo = Convert-ToWslPath $repo
    $wslImageRoot = Convert-ToWslPath $imageRoot
    $wslCommand = "export PATH=/home/shixin/.local/riscv-tools/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; cd '$wslRepo'; make -C verification/riscv_tests OUT='$wslImageRoot' -j2"
    & wsl.exe -d $WslDistribution -- bash -lc $wslCommand
    if ($LASTEXITCODE -ne 0) {
        throw "WSL standard-test build failed with exit code $LASTEXITCODE"
    }
}
else {
    if (-not (Test-Path -LiteralPath $imageRoot)) {
        throw "-SkipBuild was specified but image directory does not exist: $imageRoot"
    }
    foreach ($path in @($memhRoot, $simRoot, $logRoot)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
    New-Item -ItemType Directory -Force -Path $memhRoot, $simRoot, $logRoot | Out-Null
}

Push-Location $simRoot
try {
    & $vlib work
    if ($LASTEXITCODE -ne 0) {
        throw "vlib failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Push-Location $repo
try {
    & $vlog '-work' (Join-Path $simRoot 'work') '+define+verilog_sim' '-lint' '-f' $filelist $testbench
    if ($LASTEXITCODE -ne 0) {
        throw "vlog failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$pass = 0
$fail = 0
$unsupported = 0
$notTested = 0
$total = 0

foreach ($line in Get-Content -LiteralPath $manifest) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
        continue
    }
    $fields = $line -split "`t", 4
    if ($fields.Count -lt 4) {
        throw "Invalid manifest line: $line"
    }
    $name = $fields[0]
    $isa = $fields[1]
    $status = $fields[2]
    $comment = $fields[3]
    if ($TestFilter -and $name -notlike $TestFilter) {
        continue
    }
    $total++

    if ($status -eq 'unsupported') {
        Write-Host "MODELSIM_REGRESSION_UNSUPPORTED $name ($isa): $comment"
        $unsupported++
        continue
    }
    if ($status -eq 'not-yet-tested') {
        Write-Host "MODELSIM_REGRESSION_NOT_TESTED $name ($isa): $comment"
        $notTested++
        continue
    }
    if ($status -ne 'run' -and $status -ne 'planned') {
        throw "Invalid manifest status '$status' for $name"
    }

    $image = Join-Path $imageRoot ($name + '.elf')
    if (-not (Test-Path -LiteralPath $image)) {
        throw "Missing standard-test ELF: $image"
    }
    $memh = Join-Path $memhRoot ($name.Replace('/', '_') + '.memh')
    & py.exe -3 $converter --elf $image --output $memh
    if ($LASTEXITCODE -ne 0) {
        throw "ELF conversion failed for $name with exit code $LASTEXITCODE"
    }

    Write-Host "MODELSIM_RUN $name"
    $simArgs = @(
        '-batch',
        '-modelsimini', $modelsimIni,
        'work.tb_tcm_regression',
        "+MEMH=$(($memh.Replace('\', '/')))",
        "+TESTNAME=$name",
        "+MAX_CYCLES=$MaxCycles",
        '-do', 'run -all; quit -f'
    )
    $log = Join-Path $logRoot ($name.Replace('/', '_') + '.log')
    Push-Location $simRoot
    try {
        $output = (& $vsim @simArgs 2>&1 | Out-String)
        $rc = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    $output | Tee-Object -FilePath $log | Write-Host

    if ($rc -eq 0 -and
        $output -match 'MODELSIM_TEST_PASS' -and
        $output -match 'MODELSIM_TEST_COMPLETE' -and
        $output -notmatch 'MODELSIM_TEST_FAIL') {
        Write-Host "MODELSIM_REGRESSION_PASS $name"
        $pass++
    }
    else {
        Write-Host "MODELSIM_REGRESSION_FAIL $name (exit code $rc)"
        $fail++
    }
}

Write-Host "MODELSIM_REGRESSION_SUMMARY TOTAL=$total PASS=$pass FAIL=$fail UNSUPPORTED=$unsupported NOT_TESTED=$notTested"
if ($fail -ne 0) {
    exit 1
}
