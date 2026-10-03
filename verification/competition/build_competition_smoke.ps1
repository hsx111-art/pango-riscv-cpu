param(
    [string]$ToolchainBin = $(if ($env:RISCV_TOOLCHAIN_BIN) { $env:RISCV_TOOLCHAIN_BIN } else { 'A:\Vivado\2025.2\gnu\riscv\nt\bin' }),
    [string]$OutputRoot = '',
    [string]$PythonExe = $(if ($env:PYTHON_EXE) { $env:PYTHON_EXE } else { 'py' })
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repo '.build\competition'
}

$cc = Join-Path $ToolchainBin 'riscv64-unknown-elf-gcc.exe'
$objdump = Join-Path $ToolchainBin 'riscv64-unknown-elf-objdump.exe'
$readelf = Join-Path $ToolchainBin 'riscv64-unknown-elf-readelf.exe'
foreach ($tool in @($cc, $objdump, $readelf)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "RISC-V toolchain tool not found: $tool"
    }
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$elf = Join-Path $OutputRoot 'competition_smoke.elf'
$dump = Join-Path $OutputRoot 'competition_smoke.dump'
$readelfOut = Join-Path $OutputRoot 'competition_smoke.readelf'
$memh = Join-Path $OutputRoot 'competition.memh'
$memhConverter = Join-Path $repo 'verification\modelsim\elf_to_memh.py'
$cflags = @('-march=rv32im_zicsr_zifencei','-mabi=ilp32','-mcmodel=medany','-O2',
    '-ffreestanding','-fno-builtin','-fno-pic','-fno-stack-protector',
    '-fno-asynchronous-unwind-tables','-nostdlib','-nostartfiles','-static',
    '-mno-relax')
$ldflags = @("-T$PSScriptRoot\link_competition.ld",'-Wl,--no-relax','-Wl,--build-id=none')
& $cc @cflags @ldflags (Join-Path $PSScriptRoot 'start.S') (Join-Path $PSScriptRoot 'competition_smoke.c') '-o' $elf
if ($LASTEXITCODE -ne 0) { throw "RISC-V compilation failed with exit code $LASTEXITCODE" }
& $objdump '-d' $elf | Set-Content -LiteralPath $dump -Encoding ascii
& $readelf '-h' '-S' $elf | Set-Content -LiteralPath $readelfOut -Encoding ascii
if ($PythonExe -eq 'py') {
    & $PythonExe '-3' $memhConverter '--elf' $elf '--output' $memh '--ram-words' '16384'
}
else {
    & $PythonExe $memhConverter '--elf' $elf '--output' $memh '--ram-words' '16384'
}
if ($LASTEXITCODE -ne 0) { throw "ELF-to-memory conversion failed with exit code $LASTEXITCODE" }
Write-Host "COMPETITION_ELF=$elf"
Write-Host "COMPETITION_MEMH=$memh"
