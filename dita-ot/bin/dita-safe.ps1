# Windows-safe DITA-OT launcher.
# Avoids cmd.exe's command-line limit by reading config/env.bat as data and
# passing the complete Java invocation through a Java @argfile.
# (c) 2026 Manu Ojanen Index IT www.index.fi

$DitaArgs = @($args)

$ErrorActionPreference = 'Stop'

function Quote-JavaArgFileArgument {
    param([AllowEmptyString()][string] $Value)

    if ($null -eq $Value) {
        return '""'
    }

    # Java argument files interpret backslash escapes inside double quotes.
    # Escape both backslashes and quotes so Windows paths and arbitrary DITA
    # arguments survive the argfile parser unchanged.
    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Split-CommandLineOptions {
    param([string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    # Split ordinary Windows option strings while preserving whitespace inside
    # double-quoted values. Quote characters group a value and are not part of
    # the resulting argument.
    $result = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $inQuotes = $false

    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '"') {
            $inQuotes = -not $inQuotes
        }
        elseif ([char]::IsWhiteSpace($character) -and -not $inQuotes) {
            if ($current.Length -gt 0) {
                $result.Add($current.ToString())
                $null = $current.Clear()
            }
        }
        else {
            $null = $current.Append($character)
        }
    }

    if ($inQuotes) {
        throw "Unterminated quote in command-line options: $Value"
    }
    if ($current.Length -gt 0) {
        $result.Add($current.ToString())
    }

    return @($result)
}

$binDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ditaHome = [System.IO.Path]::GetFullPath((Join-Path $binDir '..'))
$envFile = Join-Path $ditaHome 'config\env.bat'
$javaExe = if ($env:JAVACMD) {
    $env:JAVACMD
} elseif ($env:JAVA_HOME) {
    Join-Path $env:JAVA_HOME 'bin\java.exe'
} else {
    'java.exe'
}

if ([System.IO.Path]::IsPathRooted($javaExe) -and -not (Test-Path -LiteralPath $javaExe)) {
    throw "Java executable was not found at '$javaExe'."
}

# DITA-OT integration regenerates env.bat. For install/uninstall the standard
# launcher deliberately omits plug-in libraries from the classpath, so mirror
# that behavior here.
$subcommand = if ($DitaArgs.Count -gt 0) { $DitaArgs[0] } else { '' }
$skipPluginClasspath = $subcommand -in @('install', 'uninstall')

$classPathEntries = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($env:CLASSPATH)) {
    foreach ($entry in $env:CLASSPATH.Split(';')) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            $classPathEntries.Add($entry)
        }
    }
}

if (-not $skipPluginClasspath) {
    if (-not (Test-Path -LiteralPath $envFile)) {
        throw "DITA-OT classpath configuration was not found at '$envFile'. Run DITA-OT integration first."
    }

    foreach ($line in [System.IO.File]::ReadLines($envFile)) {
        if ($line -match '^\s*set\s+"CLASSPATH=%CLASSPATH%;(?<entry>.+)"\s*$') {
            $entry = $Matches['entry'].Replace('%DITA_HOME%', $ditaHome)
            $resolvedEntry = [System.IO.Path]::GetFullPath($entry)
            # Match the standard Java launcher behavior: retain generated
            # classpath entries even if a plug-in has later been removed.
            # Java ignores non-existent classpath entries. Running
            # `dita.bat install` regenerates env.bat and removes stale entries.
            $classPathEntries.Add($resolvedEntry)
        }
    }
}

$javaArgs = New-Object System.Collections.Generic.List[string]
$javaArgs.Add('-Djava.awt.headless=true')
$javaArgs.Add('-Dcli.log-format=fancy')
$javaArgs.Add('-Dcli.color=true')
$javaArgs.Add('-Dsun.io.useCanonCaches=true')
foreach ($opt in (Split-CommandLineOptions $env:ANT_OPTS)) {
    $javaArgs.Add($opt)
}

$launcherClassPath = (Join-Path $ditaHome 'lib\ant-launcher.jar') + ';' + (Join-Path $ditaHome 'config')
$javaArgs.Add('-classpath')
$javaArgs.Add($launcherClassPath)
$javaArgs.Add("-Dant.home=$ditaHome")
$javaArgs.Add("-Ddita.dir=$ditaHome")
$javaArgs.Add('org.apache.tools.ant.launch.Launcher')

foreach ($arg in (Split-CommandLineOptions $env:ANT_ARGS)) {
    $javaArgs.Add($arg)
}

if ($classPathEntries.Count -gt 0) {
    $javaArgs.Add('-cp')
    $javaArgs.Add(($classPathEntries -join ';'))
}

foreach ($arg in $DitaArgs) {
    $javaArgs.Add($arg)
}

$javaArgs.Add('-buildfile')
$javaArgs.Add((Join-Path $ditaHome 'build.xml'))
$javaArgs.Add('-main')
$javaArgs.Add('org.dita.dost.invoker.Main')

$argFile = Join-Path ([System.IO.Path]::GetTempPath()) ("dita-safe-{0}.args" -f [guid]::NewGuid().ToString('N'))
try {
    $lines = foreach ($arg in $javaArgs) {
        Quote-JavaArgFileArgument $arg
    }
    [System.IO.File]::WriteAllLines($argFile, $lines, [System.Text.UTF8Encoding]::new($false))

    & $javaExe "@$argFile"
    $exitCode = $LASTEXITCODE
}
finally {
    Remove-Item -LiteralPath $argFile -Force -ErrorAction SilentlyContinue
}

exit $exitCode
