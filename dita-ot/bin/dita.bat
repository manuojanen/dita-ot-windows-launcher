@echo off
setlocal

rem Windows-safe DITA-OT entry point.
rem Keep the public dita.bat interface, but let PowerShell build the Java
rem invocation in an @argfile so the plug-in classpath never crosses
rem cmd.exe's command-line length limit.
rem (c) 2026 Manu Ojanen Index IT www.index.fi

set "DITA_SAFE_SCRIPT=%~dp0dita-safe.ps1"

if not exist "%DITA_SAFE_SCRIPT%" (
    echo DITA-OT launcher not found: "%DITA_SAFE_SCRIPT%" 1>&2
    endlocal & exit /b 1
)

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%DITA_SAFE_SCRIPT%" %*
set "DITA_EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %DITA_EXIT_CODE%
