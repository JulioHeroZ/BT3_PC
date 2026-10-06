function Import-BT3Toolchain {
    $locator = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path -LiteralPath $locator)) { throw 'Instale Visual Studio Build Tools com C++, ClangCL e Windows SDK.' }
    $installation = & $locator -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $installation) { throw 'Ferramentas C++ do Visual Studio nao encontradas.' }
    $vcvars = Join-Path $installation 'VC/Auxiliary/Build/vcvars64.bat'
    & cmd.exe /d /s /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
    }
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao carregar ambiente C++.' }
    $env:PATH = (Join-Path $installation 'VC/Tools/Llvm/x64/bin') + ';' + $env:PATH
    $redistRoot = Join-Path $installation 'VC/Redist/MSVC'
    $script:BT3Crt = Get-ChildItem -LiteralPath $redistRoot -Directory |
        Where-Object { $_.Name -match '^\d+\.' } | Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object {
            Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue
        } | Select-Object -ExpandProperty FullName -First 1
    if (-not $script:BT3Crt) { throw 'Redistribuivel x64 do Visual C++ nao encontrado.' }
}
