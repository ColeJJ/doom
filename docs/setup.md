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
`lsp-sonarlint`, `magit-todos`, `flamegraph`, `pg`, `pgmacs` (pg/pgmacs via `package-vc` aus Git).

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

## Troubleshooting

- **Hoher Speicher / langsam**: `lsp-java-vmargs` (Heap, Standard `-Xmx4G`) und
  `lsp-file-watch-threshold` in [`+java.el`](../+java.el) anpassen. `target/`
  wird bereits von der Dateiueberwachung ausgeschlossen.
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
