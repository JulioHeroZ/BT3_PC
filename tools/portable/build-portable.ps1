param(
    [string]$Iso = '',
    [int]$Jobs = 3,
    [string]$OutDir = '',
    [string]$Python = 'python',
    [switch]$SkipRecompile
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $OutDir) { $OutDir = Join-Path $repo 'build/manual-portable' }
if ($Jobs -lt 1) { throw 'Jobs deve ser positivo.' }
. (Join-Path $PSScriptRoot 'toolchain.ps1')
Import-BT3Toolchain
if (-not $SkipRecompile) {
    if (-not $Iso) {
        Add-Type -AssemblyName System.Windows.Forms
        $picker = New-Object System.Windows.Forms.OpenFileDialog
        $picker.Filter = 'ISO do jogo (*.iso)|*.iso'
        try {
            if ($picker.ShowDialog() -ne 'OK') { throw 'Nenhuma ISO selecionada.' }
            $Iso = $picker.FileName
        } finally { $picker.Dispose() }
    }
    $Iso = (Resolve-Path -LiteralPath $Iso).Path
    if ([IO.Path]::GetExtension($Iso) -ine '.iso') { throw 'Selecione uma ISO USA SLUS-21678.' }
    Push-Location $repo
    try {
        & $Python -u games/bt3/setup.py $Iso --jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw 'Falha na recompilacao do jogo.' }
    } finally { Pop-Location }
}
& (Join-Path $PSScriptRoot 'package_bt3_manual.ps1') -SourceRoot $repo -OutDir $OutDir -Python $Python
