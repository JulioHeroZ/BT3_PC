$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$source = Join-Path $PSScriptRoot 'bt3_build_gui.cs'
$icon = Join-Path $repo 'ps2xRuntime/src/launcher/assets/bt3.ico'
$output = Join-Path $repo 'Recompilar-BT3.exe'
$resources = Get-ChildItem -LiteralPath $PSScriptRoot -File |
    Where-Object { $_.Extension -in @('.ps1', '.cs', '.cpp', '.py', '.vsconfig') } |
    ForEach-Object { '/resource:' + $_.FullName + ',BT3Tools.' + $_.Name }
& $csc /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/win32icon:$icon" "/out:$output" @resources $source
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o frontend generico.' }
Write-Host "Pronto: $output"
