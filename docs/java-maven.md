# Java/LSP & Maven

## LSP/JDT-Features (Eclipse JDT.LS via lsp-java)

- Code-Completion (`corfu`), Quick-Docs/Hover (`lsp-ui-doc`, in deiner config: `Q`)
- Sprung zur Definition: `gd` bzw. `SPC c d`; Typ-Definition `SPC c D`
- Implementierungen (Interface -> Impl): `SPC c i`
- Referenzen / "Find Usages": `SPC c f`
- Rename-Refactoring: `SPC c r`; weitere Code-Actions: `SPC c a`
- Struktur/Outline: `SPC s i` (consult-imenu), `M-x lsp-treemacs-symbols`
- Typ-/Aufruf-Hierarchie: `M-x lsp-java-type-hierarchy`, `M-x lsp-treemacs-call-hierarchy`
- Fehlerliste (Tool-Window): `M-x lsp-treemacs-errors-list`
- Diagnose: `flycheck` + `lsp-sonarlint` (SonarLint-aehnliche Inspections)

### Runtime-Konfiguration

`lsp-java` startet JDT.LS mit Java 21 (`lsp-java-java-path`) und kompiliert das
Projekt gegen Java 17 (`lsp-java-configuration-runtimes`, Default `JavaSE-17`).
Heap und Datei-Ueberwachung sind fuer das grosse Reactor-Projekt getunt.

### Maven neu importieren ("Reload Maven Project")

Nach pom.xml-Aenderungen: `SPC m u` (`lsp-java-update-project-configuration`).

## Maven-Menue (`SPC m m`)

Transient-Menue mit Flags und Goals (laeuft im `compile`-Buffer):

- Flags: `-o` offline, `-s` skip tests (`-DskipTests`), `-T` parallel (`-T 1C`)
- Reactor: `c` compile, `t` test, `i` install, `C` clean install, `v` verify,
  `d` deploy, `D` dependency:tree
- Nur aktuelles Modul (`-pl <modul> -am`): `mc` compile, `mi` install
- `e` freies Goal eingeben (Execute Maven Goal)
- `u` Maven neu importieren (LSP)

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

## Execute Maven Goal (`SPC m t`)

Wie IntelliJs "Execute Maven Goal": `SPC m t` (`+mvn/execute-goal`) oeffnet ein
Eingabefenster mit **Verlauf** und haeufigen Goals. Der getippte Text laeuft 1:1 als
`mvn <goal>` im Reactor-Root, z.B. `clean install -DskipTests`. Mit `C-u SPC m t`
nur im Modul der aktuellen Datei (`-pl <modul> -am`).

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

1. Eintrag mit `RET` an-/abwaehlen -- gewaehlte Eintraege haben einen Haken `✓`.
2. Wenn die Auswahl passt: den Eintrag **`✔ [Fertig – Auswahl übernehmen]`** waehlen
   -> wird generiert.

`C-g` bricht komplett ab. Das `[Fertig]`-Element ist eine Anpassung in `+java.el`.

## Tests (`SPC m T`)

> Tests liegen unter `SPC m T` (Shift-T), weil `SPC m t` das freie Maven-Goal ist.

- `SPC m T t` Test (Klasse/Methode) ausfuehren
- `SPC m T a` alle Tests der Klasse
- `SPC m T d` Test debuggen
- `SPC m T D` alle Tests der Klasse debuggen
