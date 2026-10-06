param(
    [string]$SourceRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))),
    [string]$GameRoot = (Join-Path $SourceRoot 'build/manual-launcher')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
Import-BT3Toolchain
$build = Join-Path $SourceRoot 'build/bt3-launcher'
New-Item -ItemType Directory -Path $build -Force | Out-Null
New-Item -ItemType Directory -Path $GameRoot -Force | Out-Null
$source = Join-Path $PSScriptRoot 'bt3_play.cpp'
$icon = Join-Path $SourceRoot 'ps2xRuntime/src/launcher/assets/bt3.ico'
if (-not (Test-Path -LiteralPath $icon)) { throw 'Icone BT3 nao encontrado.' }
Copy-Item -LiteralPath $icon -Destination (Join-Path $build 'bt3.ico') -Force
'1 ICON "bt3.ico"' | Set-Content -LiteralPath (Join-Path $build 'bt3_play.rc') -Encoding ASCII
Push-Location $build
try {
    & rc.exe /nologo /fo bt3_play.res bt3_play.rc
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o recurso do icone BT3' }
    & cl.exe /nologo /std:c++17 /EHsc /O2 /MT /utf-8 $source bt3_play.res "/Fe:$GameRoot/Budokai Tenkaichi 3.exe" /link /SUBSYSTEM:WINDOWS user32.lib
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar Budokai Tenkaichi 3.exe' }
} finally { Pop-Location }
Write-Host "Pronto: $GameRoot/Budokai Tenkaichi 3.exe"
