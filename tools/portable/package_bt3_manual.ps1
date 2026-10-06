param(
    [string]$SourceRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))),
    [string]$OutDir = '',
    [string]$Python = 'python',
    [string]$RuntimeDir = ''
)
$ErrorActionPreference = 'Stop'
if (-not $OutDir) { $OutDir = Join-Path $SourceRoot 'build/manual-portable' }
$OutDir = [IO.Path]::GetFullPath($OutDir)
$stage = Join-Path $OutDir 'Budokai Tenkaichi 3 Portable'
$zip = Join-Path $OutDir 'Budokai Tenkaichi 3 Portable.zip'
if (Test-Path -LiteralPath $zip) { throw 'ZIP ja existe; use outra pasta de saida.' }
. (Join-Path $PSScriptRoot 'toolchain.ps1')
Import-BT3Toolchain
if (Test-Path -LiteralPath $stage) { throw 'Pacote ja existe. Use uma pasta nova para preservar a instalacao anterior.' }
New-Item -ItemType Directory -Path $stage | Out-Null
if (-not $RuntimeDir) {
    $RuntimeDir = @('build/ps2xRuntime/Release', 'build/ps2xRuntime', 'build/Release') |
        ForEach-Object { Join-Path $SourceRoot $_ } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ 'ps2EntryRunner.exe') } | Select-Object -First 1
}
if (-not $RuntimeDir) { throw 'Runner nao encontrado. Compile o jogo primeiro ou informe -RuntimeDir.' }
$runtime = $RuntimeDir
Copy-Item -LiteralPath (Join-Path $runtime 'ps2EntryRunner.exe') -Destination $stage
Copy-Item -Path (Join-Path $runtime '*.dll') -Destination $stage
& (Join-Path $PSScriptRoot 'build_bt3_launcher.ps1') -SourceRoot $SourceRoot -GameRoot $stage
Copy-Item -LiteralPath (Join-Path $SourceRoot 'ps2xRuntime/assets') -Destination $stage -Recurse
Copy-Item -LiteralPath (Join-Path $SourceRoot 'games/bt3/fps60_sites.txt') -Destination $stage
$redist = $script:BT3Crt
Copy-Item -Path (Join-Path $redist '*.dll') -Destination $stage
$saves = Join-Path $stage 'savedata'
New-Item -ItemType Directory -Path $saves | Out-Null
@'
[audio]
master_volume = 1
music_volume = 1
sfx_volume = 1
[video]
renderer = "opengl"
render_scale = 1
fullscreen = false
fps60 = false
'@ | Set-Content -LiteralPath (Join-Path $saves 'settings.toml') -Encoding ASCII
$csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$icon = Join-Path $SourceRoot 'ps2xRuntime/src/launcher/assets/bt3.ico'
& $csc /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/win32icon:$icon" "/out:$stage/Instalar-BT3.exe" (Join-Path $PSScriptRoot 'bt3_install.cs')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar instalador' }
Copy-Item -LiteralPath (Join-Path $SourceRoot 'LICENSE') -Destination $stage
@'
TESTE MANUAL - BT3 PC

Windows 10/11 x64, .NET Framework 4.5+ e driver grafico com OpenGL 3.3.
1. Extraia todo o ZIP em uma pasta com permissao de escrita (fora de Program Files).
2. Abra Instalar-BT3.exe e selecione sua ISO USA SLUS-21678.
3. Aguarde a extracao completa (aproximadamente 3 GB de dados).
4. Abra Budokai Tenkaichi 3.exe com dois cliques. A ISO nao precisa permanecer disponivel.

Este pacote usa o jogo compilado neste computador. O instalador extrai os recursos
da sua ISO; nao compila outro executavel no computador de destino.
Nao inclui a ISO, os dados extraidos ou saves pessoais.
Nao mova apenas o EXE: mantenha toda a pasta do pacote.
Dados: data/. Saves e configuracoes: savedata/. Log: logs/game-latest.log.
X confirma; C volta; Enter = START; setas navegam; Shift+Tab abre configuracoes.
Para reinstalar, preserve seus saves/mods e use outra pasta; o instalador nao
sobrescreve uma pasta data existente.

Base: https://github.com/c1b3r0s/BT3_PC
Base upstream: https://github.com/z3xox/BT3-Recomp
Licenca do port: GPL-3.0 (LICENSE). Este pacote destina-se ao teste manual local.
'@ | Set-Content -LiteralPath (Join-Path $stage 'LEIA-ME.txt') -Encoding UTF8
Write-Host "Pacote preparado em $stage"
& $Python (Join-Path $PSScriptRoot 'audit_bt3_package.py') $stage $SourceRoot
if ($LASTEXITCODE -ne 0) { throw 'Auditoria de dependencias falhou.' }
if (Test-Path -LiteralPath $zip) { throw 'ZIP ja existe; nao sobrescrever um pacote anterior.' }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
Write-Host "Copie para o outro computador: $zip"
