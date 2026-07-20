# Doom Emacs als Java/Spring-IDE (IntelliJ-Paritaet)

Diese Doku beschreibt die Erweiterungen, die Doom Emacs fuer die Entwicklung mit
Java, Spring, Maven und Kotlin (Projekt `entscheidungen`) IntelliJ-aehnlich machen.

## Aufbau der Konfiguration

- [`init.el`](../init.el) -- aktivierte Doom-Module
- [`packages.el`](../packages.el) -- zusaetzliche Pakete
- [`+java.el`](../+java.el) -- LSP/JDT-Kern, Maven, Run/Debug-Picker, Formatierung,
  Navigation, Code-Generierung, DB-Viewer, Profiler, Keybindings
- [`+git.el`](../+git.el) -- Magit/Forge (GitLab), Worktrees, magit-todos
- [`formatter/gc-eclipse-format.xml`](../formatter/gc-eclipse-format.xml) -- Eclipse-Formatter-Profil (aus IntelliJ abgeleitet)
- [`config.el`](../config.el) -- laedt `+java`/`+git` und enthaelt persoenliche Settings

## Inhaltsverzeichnis

1. [setup.md](setup.md) -- Installation, externe Tools, Inbetriebnahme, Troubleshooting
2. [java-maven.md](java-maven.md) -- LSP/JDT-Features, Navigation, Maven-Menue
3. [run-debug.md](run-debug.md) -- Run/Debug-Picker aus `.idea`, Debugger, Tests
4. [formatierung.md](formatierung.md) -- IntelliJ-Style nach JDT, `.editorconfig`
5. [datenbank.md](datenbank.md) -- Postgres-Viewer (pgmacs)
6. [profiler.md](profiler.md) -- Profiler (async-profiler) + Flamegraphs
7. [git.md](git.md) -- Magit, GitLab/Forge, Worktrees, pre-commit-Hook
8. [keybindings.md](keybindings.md) -- vollstaendiges Shortcut-Cheat-Sheet
9. [performance.md](performance.md) -- native-comp-Build + Daemon (schnell wie neovim)

## Schnellstart

```sh
brew install kotlin-language-server kotlin async-profiler
~/.config/emacs/bin/doom sync
# Emacs neu starten, dann eine .java-Datei oeffnen (JDT.LS laedt sich einmalig)
```

Details und naechste Schritte: siehe [setup.md](setup.md).
