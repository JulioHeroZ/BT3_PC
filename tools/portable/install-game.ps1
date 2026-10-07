param(
    [Parameter(Mandatory=$true)][string]$Stage,
    [Parameter(Mandatory=$true)][string]$InstallDir,
    [string]$DesktopDir = [Environment]::GetFolderPath('DesktopDirectory'),
    [string]$UserSid = ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value),
    [switch]$Elevated
)
$ErrorActionPreference = 'Stop'
$Stage = (Resolve-Path -LiteralPath $Stage).Path
$InstallDir = [IO.Path]::GetFullPath($InstallDir)
if ($InstallDir.TrimEnd('\') -eq [IO.Path]::GetPathRoot($InstallDir).TrimEnd('\')) { throw 'Escolha uma pasta para o jogo, nao a raiz do disco.' }
$marker = Join-Path $InstallDir 'installed.marker'
$pending = Join-Path $InstallDir 'installing.marker'
$completed = Test-Path -LiteralPath $marker
if ((Test-Path -LiteralPath $InstallDir) -and (Get-ChildItem -LiteralPath $InstallDir -Force) -and -not $completed -and -not (Test-Path -LiteralPath $pending)) {
    throw 'A pasta escolhida possui outros arquivos. Escolha uma pasta vazia para instalar o jogo.'
}
if (-not (Test-Path -LiteralPath (Join-Path $Stage 'data/SLUS_216.78'))) { throw 'Dados extraidos ausentes.' }
# Determine whether this destination needs administrator rights without changing its ACL.
$writable = $false
$probeFolder = $InstallDir
while (-not (Test-Path -LiteralPath $probeFolder)) { $probeFolder = Split-Path $probeFolder -Parent }
$probe = Join-Path $probeFolder ('bt3-write-test-' + [guid]::NewGuid().ToString('N'))
try { [IO.File]::WriteAllText($probe, ''); $writable = $true } catch {} finally { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe } }
if (-not $writable -and -not $Elevated) {
    Write-Host 'BT3_PROGRESS|95|Aguardando permissao do Windows para instalar na pasta escolhida'
    $powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Stage "' + $Stage + '" -InstallDir "' + $InstallDir + '" -DesktopDir "' + $DesktopDir + '" -UserSid "' + $UserSid + '" -Elevated'
    $process = Start-Process -FilePath $powershell -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'A instalacao elevada falhou. Consulte build/install-error.log.' }
    return
}
try {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    'BT3 installation in progress.' | Set-Content -LiteralPath $pending -Encoding ASCII
    Write-Host 'BT3_PROGRESS|96|Instalando o jogo na pasta escolhida'
    foreach ($item in Get-ChildItem -LiteralPath $Stage) {
        if ($item.Name -eq 'Instalar-BT3.exe') { continue }
        if ($completed -and ($item.Name -eq 'data' -or $item.Name -eq 'savedata') -and (Test-Path -LiteralPath (Join-Path $InstallDir $item.Name))) { continue }
        Copy-Item -LiteralPath $item.FullName -Destination $InstallDir -Recurse -Force
    }
    # The overlay is opened read/write; allow the installing user to edit data, not executables/DLLs.
    $sid = New-Object Security.Principal.SecurityIdentifier($UserSid)
    & icacls.exe (Join-Path $InstallDir 'data') /grant ('*' + $sid.Value + ':(OI)(CI)M') /T /C /Q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel preparar permissoes dos dados do jogo.' }
    'BT3 installation; saves and settings are stored per user.' | Set-Content -LiteralPath $marker -Encoding ASCII
    Remove-Item -LiteralPath $pending
    Write-Host 'BT3_PROGRESS|99|Criando atalho na area de trabalho'
    New-Item -ItemType Directory -Path $DesktopDir -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $DesktopDir 'Dragon Ball Budokai Tenkaichi 3.lnk'))
    $shortcut.TargetPath = Join-Path $InstallDir 'Budokai Tenkaichi 3.exe'
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = $shortcut.TargetPath + ',0'
    $shortcut.Save()
    Write-Host 'BT3_PROGRESS|100|Instalacao concluida. Use o atalho para jogar'
} catch {
    $repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    New-Item -ItemType Directory -Path (Join-Path $repo 'build') -Force | Out-Null
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $repo 'build/install-error.log')
    throw
}
