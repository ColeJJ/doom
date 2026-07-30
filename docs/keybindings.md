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
| `K`   | `+java/ensure-kotlin-output-classpath` | Kotlin-`.class`-Outputs für Java/JDT.LS-Abhängigkeiten übernehmen (nach Maven-Compile) |
| `l`   | `lsp-lens-mode` | Code-Lens (Referenz-/Implementierungszaehler) an/aus |
| `g o` | `lsp-java-generate-overrides` | Override/Implement: eine Methode waehlen -> sofort overridden |
| `g g` | `lsp-java-generate-getters-and-setters` | Getter & Setter |
| `g s` | `lsp-java-generate-to-string` | `toString()` |
| `g e` | `lsp-java-generate-equals-and-hash-code` | `equals()` & `hashCode()` |
| `P c` | `+profiler/cpu` | Profiler: CPU/Methodenlaufzeit |
| `P m` | `+profiler/alloc` | Profiler: Memory/Allokation |
| `T t` | `+test/run-at-point` | Test unter dem Cursor (Klasse#Methode) |
| `T a` | `+test/run-class` | ganze Testklasse |
| `T d` | `+test/debug-at-point` | Test unter dem Cursor debuggen |
| `T D` | `+test/debug-class` | ganze Testklasse debuggen |
| `k`   | `+idea/stop-run` | Run/Debug stoppen (siehe oben) -- Debug-Steuerung liegt unter `SPC d` (eigener Abschnitt) |

> Hinweis: Tests liegen jetzt unter `SPC m T` (Shift-T), da `SPC m t` das freie
> Maven-Goal ist.
>
> **Ergebnisanzeige (IntelliJ-Look):** Nach einem Testlauf oeffnet sich der Buffer
> `*Test-Ergebnisse*` mit Klassen-/Methodennamen, gruenem Haken `✓` bei Erfolg bzw.
> rotem `✗` bei Fehlern, Laufzeiten und -- bei Fehlern -- Meldung + Stacktrace.
> Darin: `RET` springt zur Testmethode in der Quelldatei, `g` fuehrt erneut aus,
> `q` schliesst. Der rohe Maven-Output steht weiter im `*compilation*`-Buffer.
>
> **Java vs. Kotlin:** Die Test-Runner sind modusabhaengig. In **Java**-Dateien
> laufen die **Run**-Kommandos standardmaessig ebenfalls ueber Maven Surefire
> (damit die gleiche Ergebnisliste erscheint); mit `(setq +test-use-maven-for-run nil)`
> nutzt Java wieder `dap-java`/JDT.LS (schnellerer Start, aber ohne die Liste). In
> **Kotlin** (und allen anderen) laufen sie ueber **Maven Surefire**
> (`mvn -pl MODUL -am test -Dtest=Klasse[#methode]`), weil JDT.LS nur Java-Test-
> klassen kennt -- sonst kam in `.kt`-Dateien "No class found". Debuggen in
> Kotlin startet Surefire mit JDWP auf Port `5005`; danach mit `SPC m a` (attach)
> verbinden.

## Debugging (dap-mode) -- `SPC d`

Steuerung der laufenden Debug-Session. IntelliJ-Aequivalent in Klammern.
Start i.d.R. ueber `SPC m r` (Run-Config-Picker -> Debug); ausfuehrliche Doku:
[run-debug.md](run-debug.md).

| Taste | Befehl | Wirkung |
|-------|--------|---------|
| `d d` | `dap-debug` | Debug ueber Template starten |
| `d R` | `+idea/run` | Run-Config-Picker (Run/Debug) |
| `d L` | `dap-debug-last` | letzten Debug erneut |
| `d q` | `dap-disconnect` | Session trennen/beenden |
| `d Q` | `+idea/stop-run` | alles stoppen (dap + mvn) |
| `d c` | `dap-continue` | Weiter/Resume (F9) |
| `d n` | `dap-next` | Step Over (F8) |
| `d i` | `dap-step-in` | Step Into (F7) |
| `d o` | `dap-step-out` | Step Out (Shift+F8) |
| `d h` | `dap-hydra` | **Steuer-Panel** (alle Tasten in einem Transient) |
| `d b` | `dap-breakpoint-toggle` | Breakpoint an/aus (Ctrl+F8) |
| `d B` | `dap-breakpoint-delete-all` | alle Breakpoints loeschen |
| `d C` | `dap-breakpoint-condition` | bedingter Breakpoint |
| `d l` | `dap-breakpoint-log-message` | Logpoint (loggt statt Stop) |
| `d H` | `dap-breakpoint-hit-condition` | Stop nach n Treffern |
| `d e` | `dap-eval-thing-at-point` | Ausdruck unter Cursor auswerten |
| `d E` | `dap-eval` | Ausdruck eingeben & auswerten |
| `d w` | `dap-ui-expressions-add` | Watch hinzufuegen |
| `d r` | `dap-ui-repl` | REPL |
| `d v` | `dap-ui-locals` | Locals/Variablen |
| `d x` | `dap-ui-expressions` | Watches-Fenster |
| `d k` | `dap-ui-breakpoints` | Breakpoint-Liste |
| `d s` | `dap-ui-sessions` | Sessions |
| `d f` | `dap-switch-stack-frame` | Stack-Frame wechseln |
| `d t` | `dap-switch-thread` | Thread wechseln |

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
| `K` | Kotlin-Outputs für JDT.LS-Classpath übernehmen |

## Global (`SPC`)

| Taste | Befehl | Beschreibung |
|-------|--------|--------------|
| `r r` | `+idea/run` | Run-Config starten (Run/Debug) |
| `r k` | `+idea/stop-run` | Laufenden Run stoppen (dap-Session **oder** mvn-Compilation) -- aus jedem Buffer |
| `r e` | `+idea/rerun` | **Rerun**: letzten Lauf neu starten (stop+start) -- aus jedem Buffer |
| `r h` | `+java/hotswap` | **HotSwap**: geaenderte Klassen in laufenden Debug laden -- aus jedem Buffer |
| `o d` | `+pg/open` | DB-Viewer (Postgres/pgmacs); **`C-u o d`** = direkt Tabellensuche |
| `o f` | `tu/open-in-finder` | Verzeichnis im Finder oeffnen |
| `o p` | `+treemacs/toggle` | Projekt-Sidebar (Treemacs) -- Breite passt sich automatisch dem laengsten sichtbaren Eintrag an (bis `+treemacs-max-width`, Default 70) |
| `g w` | `magit-worktree` | Git-Worktrees verwalten |

## Live Templates / Snippets

Die 73 IntelliJ Live Templates (Java, Liquibase, GC_Liquibase, Kotlin, xsl) sind
uebernommen -- Details und komplette Kuerzelliste in [live-templates.md](live-templates.md).

| Taste | Befehl | Beschreibung |
|-------|--------|--------------|
| `TAB` (Insert) | `yas-expand` | Kuerzel vor dem Cursor expandieren (z.B. `logger`, `momo`, `sod_cs`) |
| `TAB` / `S-TAB` | -- | im laufenden Template zum naechsten/vorherigen Feld |
| `SPC i s` | `yas-insert-snippet` | alle im Buffer verfuegbaren Snippets durchsuchen |
| `M-x yas-new-snippet` | -- | eigenes Snippet als Datei anlegen (in Doom nicht gebunden) |

## LSP/Navigation (Doom-Standard, `SPC c`)

| Taste | Beschreibung |
|-------|--------------|
| `SPC c g` | **Direkt zur Definition springen** (Klasse/Interface/Enum/Methode, OHNE Peek-Liste) |
| `SPC c G` | **Direkt zur Typ-Definition springen** (Typ einer Variablen: Klasse/Interface/Enum) |
| `g d` / `SPC c d` | **Direkt zur Definition springen** (LSP, kein Peek/Liste, KEIN projektweiter ripgrep-Fallback -> schnell, haengt nicht) |
| `SPC c t` | zur Typ-Definition (Doom-Standard) |
| `SPC j i` | **Super-Methode** (`lsp-java-open-super-implementation`, IntelliJ "Go to Super Method"): von der Implementierung zur Methode im Interface/Supertyp |
| `SPC j I` | **Interface <-> Impl** (`+java/toggle-impl`): zwischen `XService.java` und `XServiceImpl.java` wechseln |
| `gd` / `gD` | `gd` = zur **Definition** (bei Interfaces ins Interface); `gD` = zur **Implementierung** (`+java/implementation-smart`, wie IntelliJ Ctrl+Alt+B): genau EINE Impl -> direkt dahin, sonst Liste |
| `SPC c D` | Referenzen (Find Usages) |
| `SPC c r` | Rename |
| `SPC c B` | **Projekt pruefen / Build Project** (`+java/check-project`): ganzen Reactor kompilieren, ALLE Fehler projektweit (`]e`/`[e` navigieren); `C-u` = nur Modul + Dependents |
| `SPC c n` | **Neu: Klasse/Interface/Enum ...** (`+java/new-type`, wie IntelliJ "New"): Typ waehlen (Java-Klasse/Interface/Enum/Record/Annotation, Kotlin-Klasse/Data-Class/Interface/Object/Enum) -> Datei mit Template im aktuellen Verzeichnis anlegen. Paket wird aus dem Pfad (src/main\|test/java\|kotlin) abgeleitet; Name darf ein relatives Unterpaket enthalten (`sub.paket.Name` -> erzeugt Ordner). Auch im Baum (Treemacs `N` bzw. `c j`) ins ausgewaehlte Verzeichnis. |
| `SPC c a` | **Code-Actions / Quick-Fixes** (IntelliJ Alt+Enter): Fixes fuer Warnungen/Fehler an der Cursor-Stelle vorschlagen und auswaehlen. Verfuegbare Fixes werden als Lightbulb in der Modeline angezeigt |
| `SPC c w` / `SPC c W` | **Nächste / vorherige Warnung dieser Datei**: springt ausschließlich zwischen Flycheck-Warnungen im aktuellen Buffer (keine Fehler, Infos oder Treffer aus anderen Dateien); zyklisch am Ende/Anfang |
| `SPC c e` / `SPC c E` | **Nächster / vorheriger Fehler dieser Datei**: springt ausschließlich zwischen Flycheck-Fehlern im aktuellen Buffer (keine Warnungen, Infos oder Treffer aus anderen Dateien); zyklisch am Ende/Anfang |
| `SPC c x` | **LSP-Diagnosen dieser Datei**: Consult-Liste nur für den aktuellen Buffer |
| `SPC c X` | **LSP-Diagnosen Projekt/Workspace** (`+default/diagnostics`): bisherige Gesamtansicht über alle Dateien |
| `SPC c f` | **Format nach IntelliJ-Profil** (`+format/intellij`): Region falls aktiv, sonst Buffer -- Java/Kotlin via JDT-Profil, sonst apheleia-Fallback |
| `SPC c F` | **Format buffer/region** (`+format/region-or-buffer`, Dooms apheleia-Default) |
| `SPC j d` | **Zur Definition** (direkt per LSP, `+java/jump-to-definition`) |
| `SPC p P` | **JDT.LS: nur aktuelles Projekt behalten** (`+java/lsp-prune-to-current-project`): entfernt angesammelte Fremd-Maven-Projekte aus dem Workspace -- Fix gegen langsames/haengendes `g d` |
| `SPC j r` | **Referenzen/Find Usages** (`+java/references-smart`): genau EINE Referenz (ohne Deklaration) -> **direkt dahin springen** (wie IntelliJ), sonst Liste. Zurueck: `C-o` |
| `SPC s i` | Struktur/Outline (imenu) |
| `SPC c m` | **Methoden dieser Datei** (`consult-imenu`): Liste der Methoden/Funktionen/Klassen der aktuellen Datei, Auswahl springt hin (gleich wie `SPC s i`) |
| `SPC SPC` | **Datei im Projekt finden -- fuzzy** (`+find/find-file-fuzzy`): FLEX-Matching mit Luecken wie IntelliJ -- `AgendapunktService` findet auch `AgendapunktDummyService` |
| `SPC f c` | **Datei im Projekt finden -- wortgenau** (`projectile-find-file`, zusammenhaengender Teilstring) |

> Hinweis: Kompilierte `bin/`-Ordner (Eclipse-Build-Output, z.B. `entscheidungen-webapp/bin/...`) werden bei `SPC SPC` / `SPC f c` NICHT mehr als Vorschlag gelistet. Umgesetzt ueber `projectile-git-fd-args` (`-E bin`, fd-Weg) bzw. `projectile-git-command` (`-x bin`, git-ls-files-Fallback) in `config.el`. Falls doch noch alte bin-Pfade auftauchen: einmal `SPC p i` (Projekt-Cache invalidieren).
| `SPC f m` | **Methode im Projekt finden** (`+find/project-method`): OPTIK wie `SPC SPC`/`SPC f d` -- flache, sofort filterbare Vertico-Liste mit Methoden-Icon. Sammelt einmalig per ripgrep ALLE Java/Kotlin-Methoden im Projekt; Auswahl springt an Datei:Zeile. Aus JEDER Datei aufrufbar (kein LSP noetig). Fuer nur die aktuelle Datei: `SPC s i` (imenu) |
| `SPC f M` | **Methode finden inkl. Dependencies** (`+find/project-method-deps`): gleiche flache Vertico-Optik wie `SPC f m`, aber ripgrep ueber Projekt + alle JDT.LS-Workspace-Quellprojekte (z.B. `service-framework-core`); Projektname steht im Pfad. Reine Binaer-JARs ohne Quellen sind nicht dabei (fuer Library-Typen: `SPC s a`). Einmaliger Scan (bei mehreren grossen Projekten einige Sekunden) |
| `SPC m s` / `C-c C-c` (in `.sql`) | **SQL ausfuehren** (`+pg/run-sql`): Region bzw. Statement am Cursor auf einem gewaehlten DB-Profil ausfuehren, Ergebnis als pgmacs-Tabelle |
| `SPC s c` | **Go to Class -- schnell** (Telescope-artig: `fd` ueber .java/.kt, Icons, Preview, KEIN LSP) |
| `SPC s C` | **Symbolsuche gruendlich** (LSP-Workspace-Symbole, findet auch innere Klassen/Methoden -- langsamer) |
| `SPC s a` | **Klasse inkl. Dependencies** (JDT.LS `java/searchSymbols`, auch Klassen aus pom-JARs/JDK -- oeffnet dekompiliert via `jdt://`) |

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
- **Literale Suche als eigener Shortcut (empfohlen):**
  - `SPC s F` -> **`+search/project-literal`**: sucht KOMPLETT LITERAL (`-F`/fixed
    strings). Die Eingabe wird 1:1 gesucht -- Leerzeichen und Regex-Zeichen wie
    `.` `(` `[` `*` `?` zaehlen woertlich, nichts wird als Regex interpretiert.
  - `SPC s P` -> **`+search/project-latin1`**: literal (`-F`) **und** liest die
    Dateien als ISO-8859-1 -> ideal fuer Property-Keys wie `ent.db.server` und
    Umlaute in Latin-1-`*.properties` (siehe unten).
- **Literal auch bei `SPC s p` (ad hoc):** `SPC s p` selbst ist Regex. Fuer eine
  einmalige literale Suche die rg-Flags nach ` -- ` anhaengen (alles nach ` -- `
  geht direkt an ripgrep):
  - **Komplett literal:** `a.b(c) -- -F`
  - **Leerzeichen escapen (ohne -F):** `//\ tun` sucht exakt `// tun`.
  - **Case-sensitiv:** `-s` anhaengen; **ganzes Wort:** `-w` (z.B. `wert -- -F -w`).
- **Filtern statt suchen:** Text nach `#` filtert die bereits gefundenen
  Treffer (z.B. `tun#Service` -> rg sucht `tun`, dann Filter `Service`).
- **Latin-1-Dateien (`*.properties`) durchsuchen:** Viele `*.properties` hier sind
  ISO-8859-1 kodiert. ripgrep nimmt sonst UTF-8 an und findet **Umlaute** in diesen
  Dateien NICHT. Dafuer `SPC s P` (Shift-P) -- liest die Dateien als Latin-1 und
  sucht literal (`-F`). (`SPC s p` bleibt UTF-8-Regex fuer Java/XML mit Umlauten.)

## Git (`SPC g`)

| Taste | Beschreibung |
|-------|--------------|
| `g g` | Magit-Status |
| `g w` | Worktrees |
| `g d` | **Branch-Diff vs Abzweigpunkt** (`+git/diff-vs-base-branch`, IntelliJ "Compare with Branch"): alles, was auf diesem Branch seit dem Abzweig von `develop`/`master`/`main` passiert ist. `C-u` = Basis-Branch selbst waehlen, `C-u C-u` = inkl. ungecommitteter Aenderungen |
| `g D` | **Datei-Diff vs HEAD** (`magit-diff-buffer-file`): aktuelle (uncommittete) Aenderungen der Datei ggü. dem letzten Commit, farbig im Magit-Diff-Buffer (ersetzt Dooms `magit-file-delete`) |
| `g h` | **Datei-Historie mit Diff-Vorschau** (`+git/file-history`, Telescope `git_bufcommits`): Commits dieser Datei, live-Diff beim Blaettern |
| `g H` | **Datei-Timemachine** (`git-timemachine`): Datei-Versionen mit `n`/`p` durchblaettern |
| `g L` | **Datei-Historie (Magit-Log)** (`magit-log-buffer-file`): Commit-Log dieser Datei, `RET` = ganzer Commit |
| `g '` | Forge-Dispatch (GitLab MR/Issues) |
| `g B` / `g A` / `g t` / `g o` | Inline-Blame im Buffer (Heatmap, `RET`=Diff, `q`=aus) / Annotate separat / Time-Machine / im Browser |

### find-file / Treffer in Split-Fenster oeffnen

Standardmaessig oeffnet Enter den Treffer im selben Fenster. Um ihn stattdessen in
einem Split zu oeffnen (funktioniert in `SPC SPC`, `SPC f c`, `find-file`, Buffer-Wahl):

| Tasten | Wirkung |
|---|---|
| `Shift-Enter` (im Minibuffer) | Treffer in **vertikalem** Split (Fenster **rechts**) -- schnellste Variante |
| `C-c v` (im Minibuffer) | Treffer in **vertikalem** Split (Fenster **rechts**, nebeneinander, wie Vim `:vsplit`) |
| `C-c s` (im Minibuffer) | Treffer in **horizontalem** Split (Fenster **unten**, wie Vim `:split`) |
| `C-;` dann `V` | dasselbe ueber Embark (vertikal, rechts) |
| `C-;` dann `\|` | dasselbe ueber Embark (horizontal, unten) |
| `C-;` dann `o` | in *irgendeinem* anderen Fenster (`find-file-other-window`) |

Technik: Der Treffer wird via Embark verarbeitet; der `project-file`-Kandidat wird dabei
automatisch in den absoluten Pfad aufgeloest. Konfiguriert in `config.el`
(`+embark/find-file-vsplit` / `+vertico/open-vsplit`).
