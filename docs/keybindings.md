# Keybindings Cheat-Sheet

`SPC` = Leader. In Java-Buffern ist `SPC m` der Localleader.

## Java-Localleader (`SPC m`, nur in Java-Buffern)

| Taste | Befehl | Beschreibung |
|-------|--------|--------------|
| `m`   | `+mvn/menu` | Maven-Menue (compile/install/deploy ...) |
| `b`   | `+mvn/rebuild-project` | **Rebuild Project** (clean install -DskipTests, ganzer Reactor) |
| `t`   | `+mvn/execute-goal` | **Maven-Goal frei eingeben** (IntelliJ "Execute Maven Goal") |
| `r`   | `+idea/run` | Run-Config-Picker (dap-java), Run/Debug |
| `R`   | `+idea/run-mvn` | Run-Config via `mvn exec:java` (Jetty-Fallback) |
| `a`   | `+idea/attach` | An laufende JVM andocken (JDWP :5005) |
| `I`   | `+java/toggle-impl` | Interface <-> Impl wechseln |
| `=`   | `lsp-format-buffer` | Formatieren (JDT/IntelliJ-Style) |
| `o`   | `lsp-java-organize-imports` | Imports ordnen |
| `u`   | `lsp-java-update-project-configuration` | Maven neu importieren |
| `g o` | `lsp-java-generate-overrides` | Override/Implement: eine Methode waehlen -> sofort overridden |
| `g g` | `lsp-java-generate-getters-and-setters` | Getter & Setter |
| `g s` | `lsp-java-generate-to-string` | `toString()` |
| `g e` | `lsp-java-generate-equals-and-hash-code` | `equals()` & `hashCode()` |
| `P c` | `+profiler/cpu` | Profiler: CPU/Methodenlaufzeit |
| `P m` | `+profiler/alloc` | Profiler: Memory/Allokation |
| `T t` | Test ausfuehren | Test der Klasse/Methode |
| `T a` | alle Tests der Klasse | |
| `T d` | Test debuggen | |
| `T D` | alle Tests debuggen | |
| `d`   | `dap-hydra` | Debugger-Steuerung (in laufender Session) |

> Hinweis: Tests liegen jetzt unter `SPC m T` (Shift-T), da `SPC m t` das freie
> Maven-Goal ist.

## Java-Direkttasten (nur in Java-Buffern)

| Taste | Befehl | Beschreibung |
|-------|--------|--------------|
| `M-<up>` | `+java/previous-method` | zur vorherigen Methode/Definition springen |
| `M-<down>` | `+java/next-method` | zur naechsten Methode/Definition springen |

### `SPC m t` -- Execute Maven Goal

Oeffnet ein Eingabefenster (completing-read) mit **Verlauf** ("Recent") und
haeufigen Goals. Getippter Text laeuft 1:1 als `mvn <goal>` im Reactor-Root, z.B.
`clean install -DskipTests` oder `-pl entscheidungen-service -am test`.
Mit Praefix-Arg `C-u SPC m t` laeuft das Goal nur im Modul der aktuellen Datei
(`-pl <modul> -am`). Auch im Maven-Menue unter `SPC m m` -> `e` erreichbar.

## Maven-Menue (`SPC m m`)

| Taste | Aktion |
|-------|--------|
| `-o` / `-s` / `-T` | Flags: offline / skip tests / parallel |
| `c` `t` `i` `C` `v` `d` `D` | compile, test, install, clean install, verify, deploy, dependency:tree |
| `mc` `mi` | compile / install nur aktuelles Modul (`-pl -am`) |
| `b` | Rebuild Project (clean install -DskipTests) |
| `e` | freies Goal eingeben (Execute Maven Goal) |
| `u` | Maven neu importieren |

## Global (`SPC`)

| Taste | Befehl | Beschreibung |
|-------|--------|--------------|
| `r r` | `+idea/run` | Run-Config starten (Run/Debug) |
| `o d` | `+pg/open` | DB-Viewer (Postgres/pgmacs) |
| `o f` | `tu/open-in-finder` | Verzeichnis im Finder oeffnen |
| `g w` | `magit-worktree` | Git-Worktrees verwalten |

## LSP/Navigation (Doom-Standard, `SPC c`)

| Taste | Beschreibung |
|-------|--------------|
| `g d` / `SPC c d` | zur Definition |
| `SPC c D` | zur Typ-Definition |
| `SPC c i` | zu Implementierungen |
| `SPC c f` | Referenzen (Find Usages) |
| `SPC c r` | Rename |
| `SPC c a` | Code-Actions (inkl. Override/Implement) |
| `SPC s i` | Struktur/Outline (imenu) |

## Suche im Projekt (`SPC s p`, consult-ripgrep)

- **Projektwurzel:** `SPC s p` sucht im **Oberprojekt** (Git-Wurzel), nicht im
  einzelnen Maven-Modul. Grund: Doom wertete sonst die Eclipse-`.project`-Datei
  jedes Moduls als eigene Projektwurzel -- dieser Marker ist in `config.el`
  deaktiviert (`projectile-project-root-files-bottom-up` ohne `.project`).
  Eigene Wurzeln weiterhin per `.projectile`-Datei markierbar.
- **Exakte Suche / Leerzeichen literal:** consult zerlegt die Eingabe an
  Leerzeichen in mehrere Teilmuster und verbindet sie mit `.*` (daher matcht
  `// tun` auch `// ... tun`). Loesungen:
  - **Leerzeichen escapen:** `//\ tun` sucht exakt nach `// tun`.
  - **Komplett literal** (auch Regex-Zeichen wie `.` `(` `*`): ripgrep-Flag
    `-F` (fixed strings) anhaengen, z.B. `//\ tun -- -F`
    (alles nach ` -- ` sind zusaetzliche rg-Argumente).
- **Filtern statt suchen:** Text nach `#` filtert die bereits gefundenen
  Treffer (z.B. `tun#Service` -> rg sucht `tun`, dann Filter `Service`).

## Git (`SPC g`)

| Taste | Beschreibung |
|-------|--------------|
| `g g` | Magit-Status |
| `g w` | Worktrees |
| `g '` | Forge-Dispatch (GitLab MR/Issues) |
| `g B` / `g t` / `g o` | Blame / Time-Machine / im Browser oeffnen |
