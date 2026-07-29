# Java/LSP & Maven

## LSP/JDT-Features (Eclipse JDT.LS via lsp-java)

- Code-Completion (`corfu`), Quick-Docs/Hover (`lsp-ui-doc`, in deiner config: `Q`)
- Sprung zur Definition: `gd` bzw. `SPC c d`; Typ-Definition `SPC c D`
- Implementierungen (Interface -> Impl): `SPC c i`
- Super-/Interface-Methode (Impl-Methode -> Interface-Methode): `SPC m i` (IntelliJ "Go to Super Method") -- Cursor auf die Methode setzen; bei mehreren Supertypen erscheint eine Auswahl, bei genau einem wird direkt gesprungen
- Referenzen / "Find Usages": `SPC c f`
- Rename-Refactoring: `SPC c r`; weitere Code-Actions: `SPC c a`
- Struktur/Outline: `SPC s i` (consult-imenu), `M-x lsp-treemacs-symbols`
- Klassensuche:
  - `SPC s c` = **schnell, projektlokal** (Dateisuche via `fd` ueber .java/.kt, Icons/Preview, kein LSP)
  - `SPC s C` = **gruendlich** (LSP-Workspace-Symbole, auch innere Klassen/Methoden)
  - `SPC s a` = **inkl. Dependencies** (wie IntelliJ Cmd+O ueber Bibliotheken): sucht via JDT.LS `java/searchSymbols` auch Klassen aus den **pom-Dependencies/JARs** und dem **JDK**. Auswahl oeffnet den Inhalt als dekompilierte bzw. ueber angehaengte Sources geladene Datei (`jdt://`). Ab 2 Zeichen wird live gesucht.
- Typ-/Aufruf-Hierarchie: `M-x lsp-java-type-hierarchy`, `M-x lsp-treemacs-call-hierarchy`
- Fehlerliste (Tool-Window): `M-x lsp-treemacs-errors-list`
- Diagnose: `flycheck` + `lsp-sonarlint` (SonarLint-aehnliche Inspections)

### Runtime-Konfiguration

`lsp-java` startet JDT.LS mit Java 21 (`lsp-java-java-path`) und kompiliert das
Projekt gegen Java 17 (`lsp-java-configuration-runtimes`, Default `JavaSE-17`).
Heap und Datei-Ueberwachung sind fuer das grosse Reactor-Projekt getunt.

**Kotlin-Language-Server:** braucht **Java 21** (die 1.3.x-Builds sind fuer class
file version 65 kompiliert). Da der Daemon global `JAVA_HOME=17` erbt (fuer Maven),
wuerde `kotlin-language-server` sonst mit `UnsupportedClassVersionError` sofort
abstuerzen. Loesung in [`+java.el`](../+java.el): der Kotlin-LS-Prozess bekommt ueber
lsp-modes `environment-fn` gezielt `JAVA_HOME` = Java 21 (`+kotlin-ls-java-home`),
ohne das globale `JAVA_HOME` (Maven/JDT bleiben auf 17) zu veraendern.

**Kotlin-Syntax-Highlighting (tree-sitter):** `kotlin-ts-mode` und die
`fwcd/tree-sitter-kotlin`-Grammar muessen zueinander passen -- sonst brechen die
Font-Lock-Queries komplett ab (`treesit-query-error "Node type error"`) und es gibt
GAR KEIN Highlighting. Deshalb ist in [`packages.el`](../packages.el) eine neuere
`kotlin-ts-mode`-Version gepinnt und in [`+java.el`](../+java.el) die Grammar-Revision
auf den Branch `main` (`+kotlin-ts-grammar-revision`). Grammar bei Bruch neu bauen:
`M-x +kotlin/reinstall-grammar`, danach Emacs/Daemon neu starten (tree-sitter ersetzt
eine bereits geladene Grammar erst nach Neustart).

### Maven neu importieren ("Reload Maven Project")

Nach pom.xml-Aenderungen: `SPC m u` (`lsp-java-update-project-configuration`).

### Server bleibt am Leben (`lsp-keep-workspace-alive t`)

JDT.LS wird **nicht** heruntergefahren, wenn kein Java-Buffer mehr offen ist. Grund:
`lsp-keep-workspace-alive` ist in [`+java.el`](../+java.el) auf `t` gesetzt. Mit dem
frueheren `nil` fuhr der Server beim Wegspringen (z.B. in den Docker-Container-Buffer
oder ein anderes Projekt) herunter, sobald der letzte Java-Buffer gekillt wurde --
beim Zurueckkommen musste der komplette Maven-Reactor neu importiert werden (Minuten),
und in der Zeit gab es KEINE Vorschlaege/keine Dependencies. Mit `t` bleibt das
Projektmodell wie in IntelliJ dauerhaft geladen. Server bewusst beenden:
`M-x lsp-workspace-shutdown`; neu starten/reparieren: `M-x lsp-workspace-restart`.

**Falls doch mal die Verknuepfung fehlt** (Datei haengt im Standalone-Default-Projekt,
JDT-Log zeigt `/Datei.java` statt `/modul/.../Datei.java`): meist ein korrupter
JDT-Cache (`EOFException` beim Laden von `variablesAndContainers`). Reset:
Server beenden, `rm -rf ~/.config/emacs/.local/etc/java-workspace`, Datei neu oeffnen
(`M-x lsp`) -> sauberer Reactor-Reimport.

## Maven-Menue (`SPC m m`)

Transient-Menue mit Flags und Goals (laeuft im `compile`-Buffer):

- Flags: `-o` offline, `-s` skip tests (`-DskipTests`), `-T` parallel (`-T 1C`)
- Reactor: `c` compile, `t` test, `i` install, `C` clean install, `v` verify,
  `d` deploy, `D` dependency:tree
- Nur aktuelles Modul (`-pl <modul> -am`): `mc` compile, `mi` install
- `e` freies Goal eingeben (Execute Maven Goal)
- `u` Maven neu importieren (LSP)

### Maven-Ausgabe als Vollbild (`q` zurueck zum Code)

Alle Maven-Aufrufe -- `SPC m c`, `SPC m t`, das Maven-Menue (`SPC m m`), Rebuild
und der Maven-Run (`SPC m R`) -- oeffnen ihre Ausgabe nicht mehr im unteren
Side-Buffer. Stattdessen ersetzt der Compilation-Buffer die aktuelle Ansicht als
maximales Fenster. Das bisherige Layout mit allen Splits, Buffern und Cursor-Positionen
wird vorher gespeichert.

- `q`: Ausgabe verlassen und die vorherige Code-Ansicht exakt wiederherstellen.
- Der Maven-Prozess laeuft beim Verlassen weiter; der Ausgabe-Buffer bleibt über
  `SPC b b` erneut erreichbar.
- `]e` / `[e` bzw. `M-g n` / `M-g p`: nächster/vorheriger Compilerfehler.
- `RET`: an die Fehlerstelle im Code springen.

Das Modul wird automatisch aus dem Pfad der aktuellen Datei bestimmt (naechstes
`pom.xml`), die Reactor-Wurzel aus dem **obersten** `pom.xml`.

### Reactor-Root vs. Modul (wichtig bei "Symbol nicht gefunden")

`+mvn--root` laeuft die Verzeichniskette nach oben bis zum **obersten** `pom.xml`
(= Reactor-Root, z.B. `entscheidungen`), nicht nur bis zum naechsten Modul-`pom.xml`
(z.B. `entscheidungen-webapp`). Das ist genau das Verhalten von IntelliJ.

Hintergrund: Wuerde man Maven nur im Modul (`entscheidungen-webapp`) starten, baut
Maven dieses Modul **isoliert** und zieht seine Geschwister (model/service) aus
`~/.m2` -- also aus ggf. **veralteten JARs**. Folge sind Fehler, die in IntelliJ
nicht auftreten, z.B.:

- `Symbol nicht gefunden: Methode ...Service...` (Methode existiert nur im
  aktuellen Quellcode, nicht im installierten JAR),
- `Der Switch-Ausdruck deckt nicht alle ... Werte ab` (Enum im JAR weicht vom
  Quellcode ab).

Weil `c`/`C`/`compile`/`clean install` etc. jetzt vom Reactor-Root **ohne** `-pl`
laufen, werden model/service/webapp gemeinsam aus dem Quellcode kompiliert -- wie in
IntelliJ. Nur wirklich ein einzelnes Modul bauen willst du mit `mc`/`mi` bzw.
`C-u SPC m t` (`-pl <modul> -am`).

## Rebuild Project (`SPC m b`)

IntelliJs "Rebuild Project"-Aequivalent: `SPC m b` (`+mvn/rebuild-project`) baut das
gesamte Projekt von Grund auf neu -- `mvn clean install -DskipTests` ueber den
kompletten Reactor im Projekt-Root (`clean` wirft alle `target/`-Ausgaben weg).
Goals anpassbar via `+mvn-rebuild-goals`. Danach ggf. `SPC m u` fuer den JDT.LS-Reimport.
Auch im Maven-Menue unter `SPC m m` -> `b`.

## Projektweite Fehler / "Build Project" (`SPC m c`)

**Wichtig zur Erwartung:** LSP/JDT.LS zeigt Fehler nur fuer **geoeffnete** Dateien.
Aendert man z.B. eine **Konstruktor-Signatur**, werden die kaputten **Aufrufstellen in
nicht geoeffneten Dateien NICHT automatisch** rot markiert -- anders als IntelliJ, das
laufend das ganze Projekt kompiliert. Das ist eine Protokoll-Grenze von LSP, keine
Fehlkonfiguration.

Zwei Wege, das abzudecken:

- **`SPC m c`** (oder global **`SPC c B`**) -> `+java/check-project`: kompiliert den
  **ganzen Reactor** und listet **ALLE** Fehler projektweit ("X errors") im
  `*compilation*`-Buffer -- das IntelliJ-**"Build Project" (Ctrl+F9)**-Aequivalent.
  Navigation: **`]e`/`[e`** (naechster/vorheriger Fehler, auch `M-g n`/`M-g p`),
  `RET` springt zur Stelle. So findet man genau die Aufrufstellen, die eine
  Signatur-Aenderung gebrochen hat.
  - Mit **`C-u SPC m c`**: nur das **aktuelle Modul + dessen abhaengige Module**
    (`-pl MODUL -amd`) -- schneller, gezielt fuer Downstream-Aufrufstellen einer
    Aenderung im aktuellen Modul.
- **`SPC c X`** -> `lsp-treemacs-errors-list`: aggregiert die LSP-Diagnosen aller
  **aktuell geoeffneten** Buffer (schneller Ueberblick ohne Maven-Build).

Tipp: Wer die Aufrufstellen live sehen will, kann sie vorher per **`SPC c J`**
(Referenzen/Find Usages) auf dem Konstruktor/der Methode oeffnen -- dann greift auch
die LSP-Fehlermarkierung in diesen (nun geoeffneten) Dateien.

## Execute Maven Goal (`SPC m t`)

Wie IntelliJs "Execute Maven Goal": `SPC m t` (`+mvn/execute-goal`) oeffnet ein
Eingabefenster mit **Verlauf** und haeufigen Goals. Der getippte Text laeuft 1:1 als
`mvn <goal>` im Reactor-Root, z.B. `clean install -DskipTests`. Mit `C-u SPC m t`
nur im Modul der aktuellen Datei (`-pl <modul> -am`).

## Typ-Vorschlaege auch bei Syntaxfehlern in der Datei

Problem: `textDocument/completion` laeuft in JDT.LS ueber den **AST der aktuellen
Datei**. Ist die Datei nicht parsebar -- z.B. weil im Konstruktor-Aufruf noch ein
Parameter fehlt, den man ja gerade erst per Dependency Injection ergaenzen will --
liefert JDT.LS an der Cursorstelle kaum noch Kandidaten. Gemessen in genau so einem
Zustand: **1** Kandidat fuer das Praefix `Perso` (nur die eigene Klasse). IntelliJ hat
hier eine robustere Fehlerkorrektur im Editor-Parser.

Loesung in `+java.el`: `workspace/symbol` fragt den **Index** ab, nicht den AST --
das funktioniert auch bei kaputtem Syntaxbaum (im selben Zustand gemessen: **558**
Typen fuer `Perso`). Daraus wird eine zweite Completion-Quelle (`+java-type-capf`)
gebaut und per `cape-capf-super` **mit** der normalen LSP-Completion zusammengefuehrt.
Ergebnis: Typnamen stehen immer zur Verfuegung, die kontextgenauen LSP-Vorschlaege
bleiben zusaetzlich erhalten.

Details:

- Greift nur bei einem **typ-artigen Praefix**: mindestens 2 Zeichen, beginnt mit
  Grossbuchstaben, und **nicht** direkt nach einem Punkt (dort will man Member,
  keine Typen). Das haelt normale Variablen-/Methoden-Completion frei von Rauschen.
- Vorgeschlagen werden Klassen, Interfaces, Enums und Records (LSP-SymbolKinds 5, 10,
  11, 23). Die Annotation rechts zeigt das **Paket**.
- Der fehlende `import` wird beim Uebernehmen automatisch ergaenzt -- hinter den
  letzten Import bzw. hinter die `package`-Zeile. Uebersprungen wird er bei
  `java.lang`, bei gleichem Paket, bei bereits vorhandenem Import und bei einer
  **Namenskollision** (ein anderer Import belegt denselben einfachen Namen -- dort
  muss man voll qualifizieren, ein zweiter Import wuerde den Code brechen).
- Doppelte Eintraege (LSP und Index liefern denselben Typ) werden entfernt; behalten
  wird der LSP-Kandidat mit seinen Zusatzinfos.
- Abschalten: `M-x +java/toggle-type-completion` bzw. dauerhaft
  `+java-type-capf-enable` auf nil.

Wenn die Completion mal gar nicht aufpoppt: `C-SPC` erzwingt sie. Kommen dann immer
noch keine Kandidaten, ist der LSP-Workspace das Problem -> `SPC m L` (neu verbinden).

## Imports & Generierung

- Imports ordnen: `SPC m o` (`lsp-java-organize-imports`); zusaetzlich automatisch
  beim Speichern (`lsp-java-save-actions-organize-imports`).
- Override/Implement & Generate: siehe `SPC m g ...` in [keybindings.md](keybindings.md).

### Override (`SPC m g o`) -- Einzelauswahl

Override ist auf **Einzelauswahl** umgestellt: Eine Methode aus der Liste waehlen
(`RET`) -> sie wird **sofort** overridden. Kein An-/Abwaehlen, kein "Fertig".
Fuer mehrere Methoden den Befehl einfach erneut aufrufen. (Anpassung in `+java.el`,
ueberschreibt `lsp-java--override-methods-prompt`.)

### Mehrfachauswahl bei Generate (Getter/Setter, toString, equals)

`g g` (Getter/Setter), `g s` (toString), `g e` (equals/hashCode) oeffnen eine
**Mehrfachauswahl**. Standardmaessig sind alle Eintraege vorausgewaehlt. Bedienung:

1. Eintrag mit `RET` an-/abwaehlen -- gewaehlte Eintraege haben einen Haken `â`.
2. Wenn die Auswahl passt: den Eintrag **`â [Fertig â Auswahl Ã¼bernehmen]`** waehlen
   -> wird generiert.

`C-g` bricht komplett ab. Das `[Fertig]`-Element ist eine Anpassung in `+java.el`.

## Tests (`SPC m T`)

> Tests liegen unter `SPC m T` (Shift-T), weil `SPC m t` das freie Maven-Goal ist.

- `SPC m T t` Test (Klasse/Methode) ausfuehren
- `SPC m T a` alle Tests der Klasse
- `SPC m T d` Test debuggen
- `SPC m T D` alle Tests der Klasse debuggen

## `final`-Warnungen (lokale Variablen / Parameter)

IntelliJs Inspection *"Local variable / parameter can be final"* gibt es in JDT.LS
**nicht**. Statt eines externen Tools (Checkstyle brÃ¤uchte pro Speichern eine eigene
JVM â 1 s) nutzen wir die vorhandene **tree-sitter-Java-Grammatik**: Ein eigener,
komplett in Emacs laufender flycheck-Checker (`java-final-ts`) durchsucht den
Parse-Baum nach

- Methoden-/Konstruktor-**Parametern** (`formal_parameter`),
- **lokalen Variablen** (`local_variable_declaration`),
- **catch-Parametern** (`catch_formal_parameter`)

**ohne** `final`-Modifier und meldet sie als Warnung (JVM-frei, kein externer
Prozess). Variablen/Parameter, die spaeter im umschliessenden Scope **neu zugewiesen**
werden (per `=`, `+=`, `++`, `--` …), werden **uebersprungen** – sie koennen ja
nicht `final` sein. (Feld-/Array-Ziele wie `this.x =` oder `arr[i] =` zaehlen dabei
nicht als Reassignment der lokalen Variablen.) LÃ¤uft in `java-mode` **und** `java-ts-mode` (der Java-Parser wird bei
Bedarf angelegt). Der Checker hÃ¤ngt hinter dem `lsp`-Checker â die normalen
LSP-Diagnosen bleiben also fÃ¼hrend, die final-Hinweise kommen zusÃ¤tzlich dazu.
Parameter und lokale Variablen innerhalb von **Interfaces** werden bewusst
uebersprungen: Interface-Methoden beschreiben einen Vertrag; dort sind
`Parameter x koennte final sein`-Hinweise nicht erwuenscht.

**Steuerung:**

- `M-x +java/toggle-final-warnings` â an/aus fÃ¼r die aktuelle Sitzung.
- `+java-final-enable` (Default `t`) â dauerhaft an/aus.
- `+java-final-level` (Default `warning`) â auf `info` setzen fÃ¼r die dezente,
  IntelliJ-âWeak-Warning"-artige Darstellung (weniger auffÃ¤llig als gelbe Warnung).
- Fields (`private String x;`) werden **bewusst nicht** gemeldet (zu viel Rauschen;
  viele Felder sind absichtlich verÃ¤nderbar). Bei Bedarf lÃ¤sst sich `field_declaration`
  in `+java-final--query` ergÃ¤nzen.

## Generierte Sourcen (Swagger/OpenAPI) fuer JDT.LS sichtbar machen

Problem: Von Code-Generatoren (z.B. `swagger-codegen-maven-plugin`) erzeugte Klassen
liegen unter `target/generated-sources/.../src/gen/java/main`. JDT.LS/m2e registriert
diesen Ordner NICHT automatisch als Source-Root (das Plugin hat kein m2e-Lifecycle-
Mapping). Folge: generierte Typen (z.B. `SitzungenApi`, `ApiSitzung`) melden
"cannot be resolved to a type" und lassen sich nicht anspringen -- obwohl die Dateien
generiert auf der Platte liegen. IntelliJ markiert `target/generated-sources/**`
dagegen automatisch.

Verworfen: `java.configuration.maven.defaultMojoExecutionAction = "execute"` -- laesst
die Mojo zwar laufen, traegt den per `addCompileSourceRoot` hinzugefuegten Ordner aber
NICHT in den Eclipse-Classpath ein (empirisch getestet) und fuehrt reactorweit unnoetig
Plugins aus.

Loesung (rein lokal, ohne Aenderung der geteilten `pom.xml`): der Source-Root wird
direkt in die modul-lokale, nicht versionierte `.classpath` eingetragen. Der Ordner wird
generisch ueber das `package` der generierten `.java` abgeleitet (nicht auf Swagger
festgenagelt).

- `SPC m G` (`+java/ensure-generated-source-roots`): traegt fehlende generierte
  Source-Roots aller Reactor-Module in deren `.classpath` ein und startet bei Aenderung
  den JDT.LS-Workspace neu (mit `C-u` ohne Neustart).
- Nach `SPC m u` ("Update Project Configuration") wird die `.classpath` von JDT.LS neu
  erzeugt und unser Eintrag ist weg -- deshalb zieht ein Advice die Eintraege ~12 s
  spaeter automatisch wieder nach (und startet bei Bedarf neu).
- Voraussetzung: die Sourcen muessen generiert sein (z.B. einmal `mvn generate-sources`
  bzw. `compile` im Modul). Danach `SPC m G`.

Weitere Generatoren/Module funktionieren automatisch, solange sie nach
`target/generated-sources/...` schreiben und gueltige `package`-Deklarationen haben.
