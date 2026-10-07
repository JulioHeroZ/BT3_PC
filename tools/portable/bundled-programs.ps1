function Initialize-BT3Programs {
    $repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $archives = Join-Path $repo 'tools/portable/programs'
    $destination = Join-Path $repo 'build/portable-programs'
    $manifest = Get-Content -LiteralPath (Join-Path $archives 'manifest.json') -Raw | ConvertFrom-Json
    $paths = @{}
    foreach ($program in $manifest.programs) {
        $archive = Join-Path $archives $program.archive
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $program.sha256) {
            throw "Programa auxiliar alterado: $($program.archive)"
        }
        $folder = Join-Path $destination ($program.folder + '-' + $program.sha256.Substring(0,12))
        $paths[$program.folder] = $folder
        $marker = Join-Path $folder 'package.sha256'
        if (-not (Test-Path -LiteralPath $marker)) {
            Expand-Archive -LiteralPath $archive -DestinationPath $folder -Force
            $program.sha256 | Set-Content -LiteralPath $marker -Encoding ASCII
        } elseif ((Get-Content -LiteralPath $marker -Raw).Trim() -ine $program.sha256) {
            throw "Cache desatualizado: use outra pasta de build para $($program.folder)."
        }
    }
    $env:PATH = (Join-Path $paths['cmake'] 'bin') + ';' +
                $paths['ninja'] + ';' +
                (Join-Path $paths['git'] 'cmd') + ';' + $env:PATH
    return [pscustomobject]@{
        Python = Join-Path $paths['python'] 'python.exe'
        Recompiler = Join-Path $paths['recompiler'] 'ps2_recomp.exe'
        BuildToolsInstaller = Join-Path $paths['vs-buildtools'] 'vs_buildtools.exe'
    }
}
