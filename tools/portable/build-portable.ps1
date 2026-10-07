param(
    [string]$Iso = '',
    [int]$Jobs = 3,
    [string]$OutDir = '',
    [string]$Python = '',
    [switch]$SkipRecompile,
    [string]$InstallDir = '',
    [string]$DesktopDir = [Environment]::GetFolderPath('DesktopDirectory')
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $OutDir) { $OutDir = Join-Path $repo 'build/manual-portable' }
if ($Jobs -lt 1) { throw 'Jobs deve ser positivo.' }
Write-Host 'BT3_PROGRESS|1|Preparando as ferramentas de compilacao'
. (Join-Path $PSScriptRoot 'bundled-programs.ps1')
$programs = Initialize-BT3Programs
if (-not $Python) { $Python = $programs.Python }
$env:PS2X_RECOMP = $programs.Recompiler
. (Join-Path $PSScriptRoot 'toolchain.ps1')
Import-BT3Toolchain
Write-Host 'BT3_PROGRESS|8|Ferramentas prontas'
if ($InstallDir -and -not $Iso) { throw 'A instalacao integrada precisa da ISO selecionada.' }
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
        Write-Host 'BT3_PROGRESS|10|Analisando a ISO e gerando o codigo do jogo'
        & $Python -u games/bt3/setup.py $Iso --jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw 'Falha na recompilacao do jogo.' }
    } finally { Pop-Location }
}
Write-Host 'BT3_PROGRESS|85|Preparando os executaveis e verificando dependencias'
& (Join-Path $PSScriptRoot 'package_bt3_manual.ps1') -SourceRoot $repo -OutDir $OutDir -Python $Python
if ($InstallDir) {
    $Iso = (Resolve-Path -LiteralPath $Iso).Path
    $stage = Join-Path $OutDir 'Budokai Tenkaichi 3 Portable'
    Write-Host 'BT3_PROGRESS|90|Extraindo musicas, imagens e demais recursos da mesma ISO'
    $extract = Start-Process -FilePath (Join-Path $stage 'Instalar-BT3.exe') -ArgumentList @('--install', ('"' + $Iso + '"')) -PassThru -Wait -WindowStyle Hidden
    if ($extract.ExitCode -ne 0) { throw 'Falha ao extrair os recursos. Consulte install-error.log na pasta do pacote.' }
    & (Join-Path $PSScriptRoot 'install-game.ps1') -Stage $stage -InstallDir $InstallDir -DesktopDir $DesktopDir
} else {
    Write-Host 'BT3_PROGRESS|100|Pacote portatil gerado'
}
