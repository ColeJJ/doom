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
| `k`   | `+idea/stop-run` | Laufenden Run stoppen (dap-Session **oder** mvn-Compilation) -- sofort, nicht blockierend |
| `e`   | `+idea/rerun` | **Rerun**: letzten Lauf neu starten (stoppt vorher, wie IntelliJs Rerun) |
| `a`   | `+idea/attach` | An laufende JVM andocken (JDWP :5005) |
| `h`   | `+java/hotswap` | **HotSwap**: geaenderte Klassen in die laufende Debug-Session laden (kein Rebuild/Neustart) |
| `I`   | `+java/toggle-impl` | Interface <-> Impl wechseln (Datei-Ebene) |
| `i`   | `lsp-java-open-super-implementation` | **Zur Super-/Interface-Methode springen** (IntelliJ "Go to Super Method") |
| `=`   | `lsp-format-buffer` | Formatieren (JDT/IntelliJ-Style) |
| `o`   | `lsp-java-organize-imports` | Imports ordnen |
| `u`   | `lsp-java-update-project-configuration` | Maven neu importieren |
| `l`   | `lsp-lens-mode` | Code-Lens (Referenz-/Implementierungszaehler) an/aus |
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

> **Maven auch ausserhalb von Java-Buffern:** Das schlanke Maven-Set (`m` Menue,
> `b` Rebuild, `t` Goal, `u` Reimport) ist auch in `*.properties` (conf-mode) und in
> `pom.xml`/XML (nxml-mode) verfuegbar -- also `SPC m m` etc. funktioniert dort jetzt.

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
| `r k` | `+idea/stop-run` | Laufenden Run stoppen (dap-Session **oder** mvn-Compilation) -- aus jedem Buffer |
| `r e` | `+idea/rerun` | **Rerun**: letzten Lauf neu starten (stop+start) -- aus jedem Buffer |
| `r h` | `+java/hotswap` | **HotSwap**: geaenderte Klassen in laufenden Debug laden -- aus jedem Buffer |
| `o d` | `+pg/open` | DB-Viewer (Postgres/pgmacs) |
| `o f` | `tu/open-in-finder` | Verzeichnis im Finder oeffnen |
| `o p` | `+treemacs/toggle` | Projekt-Sidebar (Treemacs) -- Breite passt sich automatisch dem laengsten sichtbaren Eintrag an (bis `+treemacs-max-width`, Default 70) |
| `g w` | `magit-worktree` | Git-Worktrees verwalten |

## LSP/Navigation (Doom-Standard, `SPC c`)

| Taste | Beschreibung |
|-------|--------------|
| `SPC c g` | **Direkt zur Definition springen** (Klasse/Interface/Enum/Methode, OHNE Peek-Liste) |
| `SPC c G` | **Direkt zur Typ-Definition springen** (Typ einer Variablen: Klasse/Interface/Enum) |
| `g d` / `SPC c d` | zur Definition -- oeffnet wegen `+peek` ein **Peek-Fenster mit Liste** |
| `SPC c t` | zur Typ-Definition (Doom-Standard) |
| `SPC c i` | zu Implementierungen (Peek) |
| `SPC c D` | Referenzen (Find Usages) |
| `SPC c r` | Rename |
| `SPC c a` | Code-Actions (inkl. Override/Implement) |
| `SPC c j` | Klasse/Symbol projektweit (`consult-lsp-symbols`) |
| `SPC s i` | Struktur/Outline (imenu) |
| `SPC s c` | **Go to Class -- schnell** (Telescope-artig: `fd` ueber .java/.kt, Icons, Preview, KEIN LSP) |
| `SPC s C` | **Symbolsuche gruendlich** (LSP-Workspace-Symbole, findet auch innere Klassen/Methoden -- langsamer) |

> **Direkt springen statt Peek:** `gd`/`SPC c d` zeigt durch das Modul-Flag
> `(lsp +peek)` eine Peek-Liste. Wenn du **sofort in die Klasse/das Interface/Enum**
> willst, nimm `SPC c g` (bzw. `SPC c G` fuer den Typ einer Variablen). Diese rufen
> den LSP-Sprung direkt auf (via xref) und landen ohne Umweg in der Quelle.

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
- **Latin-1-Dateien (`*.properties`) durchsuchen:** Viele `*.properties` hier sind
  ISO-8859-1 kodiert. ripgrep nimmt sonst UTF-8 an und findet **Umlaute** in diesen
  Dateien NICHT. Dafuer gibt es `SPC s P` (Shift-P) -- identisch zu `SPC s p`, liest
  die Dateien aber als Latin-1. (`SPC s p` bleibt UTF-8 fuer Java/XML mit Umlauten.)

## Git (`SPC g`)

| Taste | Beschreibung |
|-------|--------------|
| `g g` | Magit-Status |
| `g w` | Worktrees |
| `g '` | Forge-Dispatch (GitLab MR/Issues) |
| `g B` / `g t` / `g o` | Blame / Time-Machine / im Browser oeffnen |
