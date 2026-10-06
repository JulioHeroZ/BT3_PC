function Import-BT3VsEnvironment([string]$Installation) {
    $vcvars = Join-Path $Installation 'VC/Auxiliary/Build/vcvars64.bat'
    & cmd.exe /d /s /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
    }
    if ($LASTEXITCODE -ne 0 -or -not $env:WindowsSdkDir -or -not $env:WindowsSDKVersion) { return $false }
    $header = Join-Path $env:WindowsSdkDir ('Include/' + $env:WindowsSDKVersion.TrimEnd('\') + '/um/Windows.h')
    return ((Test-Path -LiteralPath $header) -and (Test-Path -LiteralPath (Join-Path $Installation 'VC/Tools/Llvm/x64/bin/clang-cl.exe')))
}

function Import-BT3Toolchain {
    $locator = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $installation = $null
    if (Test-Path -LiteralPath $locator) {
        $installation = & $locator -latest -version '[17.0,18.0)' -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.Llvm.Clang -property installationPath
    }
    $ready = $false
    if ($installation) { $ready = Import-BT3VsEnvironment $installation }
    if (-not $ready) {
        . (Join-Path $PSScriptRoot 'bundled-programs.ps1')
        $programs = Initialize-BT3Programs
        $installer = $programs.BuildToolsInstaller
        if ((Get-AuthenticodeSignature -LiteralPath $installer).Status -ne 'Valid') { throw 'Assinatura do instalador Microsoft invalida.' }
        Write-Host 'Instalando Visual Studio 2022 Build Tools, ClangCL e Windows SDK. Autorize o UAC do Windows.'
        $arguments = '--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Llvm.Clang --add Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset --includeRecommended'
        $setup = Start-Process -FilePath $installer -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru -Wait
        if ($setup.ExitCode -eq 3010 -or $setup.ExitCode -eq 1641) { throw 'Ferramentas instaladas. Reinicie o Windows e execute novamente para compilar.' }
        if ($setup.ExitCode -ne 0) { throw "Instalacao do Build Tools falhou: $($setup.ExitCode)" }
        $installation = & $locator -latest -version '[17.0,18.0)' -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.Llvm.Clang -property installationPath
        if (-not $installation) { throw 'Build Tools com ClangCL nao encontrado apos a instalacao.' }
        if (-not (Import-BT3VsEnvironment $installation)) { throw 'Compilador ou Windows SDK incompleto apos a instalacao.' }
    }
    $env:PATH = (Join-Path $installation 'VC/Tools/Llvm/x64/bin') + ';' + $env:PATH
    $redistRoot = Join-Path $installation 'VC/Redist/MSVC'
    $script:BT3Crt = Get-ChildItem -LiteralPath $redistRoot -Directory |
        Where-Object { $_.Name -match '^\d+\.' } | Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object {
            Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue
        } | Select-Object -ExpandProperty FullName -First 1
    if (-not $script:BT3Crt) { throw 'Redistribuivel x64 do Visual C++ nao encontrado.' }
}
