function Import-BT3VsEnvironment([string]$Installation) {
    $vcvars = Join-Path $Installation 'VC/Auxiliary/Build/vcvars64.bat'
    $clang = Join-Path $Installation 'VC/Tools/Llvm/x64/bin/clang-cl.exe'
    if (-not (Test-Path -LiteralPath $vcvars) -or -not (Test-Path -LiteralPath $clang)) { return $false }
    # Do not let SDK values from an earlier candidate make a broken instance look ready.
    $env:WindowsSdkDir = $null
    $env:WindowsSDKVersion = $null
    & cmd.exe /d /s /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
    }
    if ($LASTEXITCODE -ne 0 -or -not $env:WindowsSdkDir -or -not $env:WindowsSDKVersion) { return $false }
    $sdk = $env:WindowsSDKVersion.TrimEnd('\')
    foreach ($file in @("Include/$sdk/um/Windows.h", "Lib/$sdk/um/x64/kernel32.lib", "Lib/$sdk/ucrt/x64/ucrt.lib")) {
        if (-not (Test-Path -LiteralPath (Join-Path $env:WindowsSdkDir $file))) { return $false }
    }
    if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue) -or -not (Get-Command rc.exe -ErrorAction SilentlyContinue)) { return $false }
    $crt = Join-Path $Installation 'VC/Redist/MSVC'
    if (-not (Test-Path -LiteralPath $crt)) { return $false }
    $dll = Get-ChildItem -LiteralPath $crt -Filter 'vcruntime140.dll' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]x64[\\/]' } | Select-Object -First 1
    return [bool]$dll
}

function Get-BT3VsInstallations {
    $locator = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (Test-Path -LiteralPath $locator) {
        # Inspect incomplete installations too; component metadata alone is not a readiness check.
        & $locator -all -products '*' -version '[17.0,18.0)' -sort -property installationPath
        if ($LASTEXITCODE -ne 0) { throw "Falha ao consultar o Visual Studio: $LASTEXITCODE" }
    }
}

function Find-BT3Toolchain([string]$Preferred = '') {
    $candidates = @()
    if ($Preferred) { $candidates += $Preferred }
    $candidates += @(Get-BT3VsInstallations)
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Import-BT3VsEnvironment $candidate)) { return $candidate }
    }
}

function Import-BT3Toolchain {
    $installation = Find-BT3Toolchain
    if (-not $installation) {
        . (Join-Path $PSScriptRoot 'bundled-programs.ps1')
        $programs = Initialize-BT3Programs
        $installer = $programs.BuildToolsInstaller
        if ((Get-AuthenticodeSignature -LiteralPath $installer).Status -ne 'Valid') { throw 'Assinatura do instalador Microsoft invalida.' }
        $existing = @(Get-BT3VsInstallations) | Select-Object -First 1
        $target = if ($existing) { $existing } else { Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/2022/BT3BuildTools' }
        Write-Host 'BT3_PROGRESS|3|Preparando automaticamente o compilador e o Windows SDK. Autorize o UAC do Windows'
        $mode = if ($existing) { 'modify --channelId VisualStudio.17.Release ' } else { '' }
        $arguments = $mode + '--installPath "' + $target + '" --quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Llvm.Clang --add Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset --add Microsoft.VisualStudio.Component.Windows11SDK.26100 --includeRecommended'
        $setup = Start-Process -FilePath $installer -ArgumentList $arguments -Verb RunAs -PassThru -Wait
        $exitCode = $setup.ExitCode
        Write-Host "Build Tools terminou com codigo $exitCode. Verificando os arquivos instalados."
        if ($exitCode -notin @(0, 3010, 1641)) { throw "Instalacao do Build Tools falhou: $exitCode. Consulte os logs dd_* em %TEMP%." }
        # The bootstrapper has completed; allow registration to settle and check actual files.
        for ($attempt = 0; $attempt -lt 12; $attempt++) {
            $installation = Find-BT3Toolchain $target
            if ($installation) { break }
            if ($attempt -lt 11) { Start-Sleep -Seconds 5 }
        }
        if (-not $installation) {
            if ($exitCode -in @(3010, 1641)) { throw 'Ferramentas instaladas, mas o Windows precisa reiniciar antes de continuar. Reinicie e abra este EXE novamente; a ISO e o destino foram preservados.' }
            throw "O instalador terminou, mas compilador, SDK ou redistribuivel ainda estao incompletos em $target. Consulte os logs dd_* em %TEMP%."
        }
        if ($exitCode -in @(3010, 1641)) { Write-Host 'O instalador indicou reinicio pendente, mas as ferramentas ja estao disponiveis. Continuando a compilacao.' }
    }
    Write-Host "Ferramentas verificadas em: $installation"
    $env:PATH = (Join-Path $installation 'VC/Tools/Llvm/x64/bin') + ';' + $env:PATH
    $redistRoot = Join-Path $installation 'VC/Redist/MSVC'
    $script:BT3Crt = Get-ChildItem -LiteralPath $redistRoot -Directory |
        Where-Object { $_.Name -match '^\d+\.' } | Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object {
            Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue
        } | Select-Object -ExpandProperty FullName -First 1
    if (-not $script:BT3Crt) { throw 'Redistribuivel x64 do Visual C++ nao encontrado.' }
}
