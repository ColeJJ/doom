# Setup & Inbetriebnahme

## Voraussetzungen (bereits vorhanden)

- Emacs 30.2 (mit libxml-Support fuer das Parsen der IntelliJ-Run-Configs)
- Maven 3.9.11
- JDKs: Temurin 8/11/17/21. JDT.LS laeuft auf Java 21, das Projekt baut gegen Java 17.

## Externe Tools installieren

```sh
brew install kotlin-language-server   # Kotlin-LSP
brew install kotlin                    # kotlinc (fuer flycheck-kotlin)
brew install async-profiler            # Java-Profiler (asprof), siehe profiler.md
brew install --cask jdk-mission-control  # optional: JFR-Analyse (Heap etc.)
```

## Doom synchronisieren

Nach Aenderungen an `init.el`/`packages.el`:

```sh
~/.config/emacs/bin/doom sync
```

Danach Emacs neu starten. Die installierten Pakete:
`lsp-sonarlint`, `magit-todos`, `flamegraph`, `magit-delta`, `pg`, `pgmacs`
(pg/pgmacs via `package-vc` aus Git). `magit-delta` braucht zusaetzlich das CLI
`delta` (`brew install git-delta`).

## Erststart

- Beim ersten Oeffnen einer `.java`-Datei laedt `lsp-java` automatisch den
  Eclipse JDT Language Server herunter (einmalig, kann dauern). Ebenso werden
  DAP- und SonarLint-Komponenten nachgeladen.
- Falls JDT.LS nicht startet: `M-x lsp-doctor`, bzw. `lsp-java-java-path` in
  [`+java.el`](../+java.el) pruefen (muss auf Java 21 zeigen).

## Zugangsdaten (~/.authinfo bzw. ~/.authinfo.gpg)

GitLab (Forge) -- siehe [git.md](git.md):

```
machine gitlab.guidecom.local/api/v4 login <user>^forge password <token>
```

Postgres (pgmacs) -- siehe [datenbank.md](datenbank.md):

```
machine localhost port 5432 login <user> password <geheim>
machine localhost port 5433 login <user> password <geheim>
```

## Performance ("wird beim Nutzen immer langsamer")

> **Der groesste Hebel** (Emacs deutlich schneller als IntelliJ, wie neovim) ist ein
> **native-comp-Emacs-Build + Daemon**. Das ist in einer eigenen Anleitung beschrieben:
> **[performance.md](performance.md)** (emacs-plus@30, Wrapper-Stolperstein, `e`/`et`
> via emacsclient). Ergebnis hier: Datei-Oeffnen von ~2 s auf ~0,02 s.

Zusaetzlich sind gegen die progressive Verlangsamung in einer Sitzung mehrere
Stellschrauben gesetzt (siehe `config.el` und `+java.el`):

- **Font-Cache nicht kompaktieren** (`inhibit-compacting-font-caches t`): der mit
  Abstand haeufigste Grund fuer "immer langsamer" bei Icon-Fonts (corfu/vertico
  `+icons`). Dazu `fast-but-imprecise-scrolling`, `redisplay-skip-fontification-on-input`,
  `jit-lock-defer-time 0`, `idle-update-delay 1.0`.
- **GC entspannt** (`gcmh-high-cons-threshold` = 256 MB): weniger GC-Pausen waehrend
  der Arbeit.
- **LSP weniger eifrig**: `lsp-idle-delay 1.0`, `lsp-enable-symbol-highlighting nil`
  (kein Neu-Highlight bei jeder Cursorbewegung), Breadcrumb/Modeline-Code-Actions/
  On-Type-Format aus, `lsp-log-io nil`, Datei-Watcher-Schwelle gesenkt + mehr Ordner
  ignoriert (`.git`, `build`, `out`, `dist`, `bin`, `logs` ...).
- **Code-Lens** (Referenz-/Implementierungszaehler ueber Methoden) ist der groesste
  verbleibende Dauer-Kostenfaktor in grossen Projekten. Bei Bedarf pro Buffer mit
  `SPC m l` (`lsp-lens-mode`) an-/ausschalten.

## Troubleshooting

- **Hoher Speicher / langsam**: `lsp-java-vmargs` (Heap, Standard `-Xmx4G`) und
  `lsp-file-watch-threshold` in [`+java.el`](../+java.el) anpassen. `target/`
  wird bereits von der Dateiueberwachung ausgeschlossen. Siehe auch Abschnitt
  **Performance** oben.
- **Kotlin-LSP startet nicht**: pruefen, ob `kotlin-language-server` im `PATH` ist.
- **pgmacs fehlt**: `doom sync` erneut ausfuehren (Installation via `package-vc`).
- **Run-Config-Picker leer**: es werden nur Configs vom Typ `Application` aus
  `.idea/runConfigurations/` gelesen; das Projekt muss als Projekt erkannt sein.
- **`vscode.java.resolveClasspath failed` / "does not support workspace/executeCommand"**:
  Es laeuft kein JDT.LS. Mit `+tree-sitter` oeffnen `.java`-Dateien in `java-ts-mode`;
  `+java.el` startet `lsp!` daher auch dort. Nach Config-Reload die `.java`-Datei einmal
  neu oeffnen (oder `M-x lsp`) und das Projekt importieren lassen. Fuer den Jetty-Start
  ohne JDT.LS: `SPC m R` (mvn exec:java).
- **Keine Code-Vorschlaege / "Corfu detected an error: ... does not support method
  textDocument/completion"** und/oder **"Wrong type argument: json-value-p,
  set-from-style"**: Ursache war, dass `lsp-java` `java.format.tabSize` aus
  `c-basic-offset` berechnet; in `java-ts-mode` war das der Symbol-Default
  `set-from-style` -> der Konfigurations-/`didOpen`-Versand an JDT.LS brach ab, der
  Buffer war an keinem completion-faehigen Server registriert. Fix in `+java.el`:
  `(setq-default c-basic-offset 2)`. Zusaetzlich ist der Spring-Boot-LS (`boot-ls`,
  STS4) deaktiviert (`lsp-java-boot-enabled nil` + `lsp-disabled-clients`), da er hier
  nur fehlschlug ("Failed to create connection to boot-ls"). Nach `doom/reload` die
  `.java`-Datei neu oeffnen.
- **`boot-ls` soll wieder aktiv sein** (nur bei echtem Spring Boot): in `+java.el`
  `lsp-java-boot-enabled` auf `t` setzen und `boot-ls` aus `lsp-disabled-clients`
  entfernen; ausserdem muss der Boot-Server-Jar unter
  `<lsp-java-server-install-dir>/boot-server/` vorhanden sein.
