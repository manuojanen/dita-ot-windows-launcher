# dita-ot-windows-launcher
Windows-safe DITA-OT launcher

## Included launcher files

The `bin` directory contains launcher-related files:

- `dita.bat` is the compatibility entry point. It invokes
  `dita-safe.ps1` with the original command-line arguments and returns the
  PowerShell launcher's exit code to the caller.
- `dita-safe.ps1` builds the complete Java invocation in a temporary Java
  argument file and starts Java with `java.exe @argument-file`.

## Why the launcher is needed

The standard Windows `dita.bat` reads the generated `config/env.bat` file and
passes the resulting plug-in classpath to Java on the `cmd.exe` command line.
With many plug-ins, long installation paths, and long publication paths, the
expanded command can exceed the Windows command processor's 8191-character
limit. DITA-OT issue #2827 tracks this problem:

https://github.com/dita-ot/dita-ot/issues/2827

`dita-safe.ps1` avoids that limit by reading `config/env.bat` as data rather
than executing it. It resolves the generated plug-in classpath in PowerShell
and writes the Java options, classpath, Ant launcher arguments, and DITA
arguments to a UTF-8 argument file. Only the short `java.exe @file` command is
passed to the operating system.

The launcher preserves the relevant behavior of the standard DITA-OT Windows
launcher:

- `JAVACMD` takes precedence over `JAVA_HOME`, with `java.exe` as the fallback.
- Existing `CLASSPATH`, `ANT_OPTS`, and `ANT_ARGS` values are retained.
- Plug-in libraries listed in `config/env.bat` are included for normal DITA
  processing.
- Plug-in libraries are omitted for the `install` and `uninstall` subcommands,
  matching the standard launcher behavior.
- The Java process exit code is returned.
- The temporary argument file is removed after the Java process exits.

Java argument files require Java 9 or newer.
