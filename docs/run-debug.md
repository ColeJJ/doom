# Run & Debug (aus .idea/runConfigurations)

Die IntelliJ-Run-Configs des Projekts werden direkt aus
`.idea/runConfigurations/*.xml` gelesen (Typ `Application`) -- IntelliJ bleibt
also die einzige Pflegestelle.

## Picker (wie "find file")

- `SPC m r` (oder global `SPC r r`) -> `+idea/run`
  1. Run-Config auswaehlen (completing-read)
  2. Aktion waehlen: **Run** (ohne Debugger) oder **Debug** (mit Debugger)
- Start ueber `dap-java`: Main-Klasse, Modul, VM-Parameter, Env und Working-Dir
  werden aus der XML uebernommen.

## Fallback: Start ueber `mvn exec:java` (zuverlaessig fuer den Jetty-Starter)

Der Jetty-Starter (`JettyStarterXML`) wird in IntelliJ ueber den Modul-Classpath
gestartet. Falls der von JDT berechnete Classpath nicht passt, gibt es:

- `SPC m R` -> `+idea/run-mvn`
  - Profil `ent-dev`, SSL-Flags, Env als Prozessumgebung, VM-Parameter via
    `MAVEN_OPTS`, `compile exec:java` mit `-Dexec.classpathScope=compile` (Profil
    `ent-dev` legt die conf auf den Classpath, siehe unten).
  - Arbeitsverzeichnis = `WORKING_DIRECTORY` aus der XML (`$PROJECT_DIR$` wird
    aufgeloest, `~` wird expandiert; Existenz wird vorher geprueft).
  - Bei **Debug** wird JDWP auf Port `5005` geoeffnet
    (`-agentlib:jdwp=...,suspend=n,address=*:5005`).

### Stoppen & Rerun

- `SPC m k` (oder global `SPC r k`) -> `+idea/stop-run`: beendet den laufenden Run
  **sofort und nicht-blockierend**. dap-Sessions werden status-basiert erkannt
  (`dap--session-running`) und via async `dap-disconnect` terminiert (kein
  *synchrones* `dap-request`, das Emacs bei haengendem Jetty einfrieren wuerde).
  Bei `SPC m R`/`mvn exec:java` wird der **komplette Prozessbaum** beendet
  (Shell -> `mvn` -> `java`/Jetty). Das ist wichtig, weil `kill-compilation` nur
  SIGINT an die Shell schickt -- das Kind `java` wuerde sonst als Waise
  weiterlaufen und den Port (HTTP bzw. JDWP `:5005`) halten.
- `SPC m e` (oder global `SPC r e`) -> `+idea/rerun`: startet den **zuletzt**
  gestarteten Lauf (egal ob `SPC m r`/dap oder `SPC m R`/mvn) ohne erneute Auswahl
  neu -- wie IntelliJs *Rerun*. Es stoppt vorher (inkl. Prozessbaum, s.o.) und
  startet nach ~1,5 s -- wenn der Port sicher frei ist -- dieselbe Run-Config mit
  derselben Aktion (Run/Debug) neu. Sollte ein Rerun doch mal mit "address already
  in use" scheitern, einfach `SPC m k` und danach erneut `SPC m e`.

### DB-/Profil-Defaults: Maven-Profil `ent-dev` (`ent.db.server` & Co.)

Die `<envs>` der Run-Config setzen nur einen Teil der DB-Parameter (z.B.
`ent.db.type=postgres`, `ent.db.port=5432`). Werte wie **`ent.db.server=localhost`**
und `ent.db.database` kommen aus
`entscheidungen-webapp/src/test/resources/conf/ent.application.properties`.

Diese Datei kommt ueber das Maven-Profil **`ent-dev`** auf den Classpath: die
`entscheidungen-webapp/pom.xml` haengt im Profil `ent-dev`
`src/test/resources/conf` als `<resource>` an -> der Inhalt landet im
**Classpath-Root** von `target/classes` (der pom-Kommentar sagt: "legt IntelliJ
... auf den Klassenpfad"). In IntelliJ ist das Profil im Maven-Reiter angehakt.

- **`SPC m R` (`+idea/run-mvn`, mvn exec:java)**: startet mit `-Pent-dev ... compile
  exec:java -Dexec.classpathScope=compile`. `compile` fuehrt `process-resources`
  aus und kopiert die conf dank `ent-dev` in den Classpath-Root. `classpathScope`
  bleibt bewusst `compile` (nicht `test`), sonst landen Test-Abhaengigkeiten wie
  h2/junit auf dem Laufzeit-Classpath -- das tut IntelliJ auch nicht.
- **`SPC m r` (`+idea/run`, dap-java)**: JDT.LS/dap kennen das `ent-dev`-Profil
  **nicht**. Damit es trotzdem wie IntelliJ laeuft, haengt `+idea--launch` die in
  `+idea-extra-classpath-dirs` (Default `("src/test/resources/conf")`) gelisteten
  Verzeichnisse **vorne** an den von JDT aufgeloesten Classpath.

Ohne diese Dateien bricht Spring mit
`Could not resolve placeholder 'ent.db.server'` ab (im Log davor:
`'class path resource [ent.application.properties]' does not exist. Skipping`),
obwohl IntelliJ problemlos startet.

### "Build before run" (abhaengige Module / `~/.m2`)

Wie in IntelliJ wird vor dem Start standardmaessig der **Reactor** gebaut:

```
mvn -Pent-dev -pl <modul> -am -Dmaven.test.skip=true install
```

- `-am` baut das Modul **samt aller benoetigten Geschwister-Module**
  (`model`, `service`, `dao`, `basis`, ...) aus dem **lokalen Quellcode** und legt
  sie in `~/.m2` ab. Das ist noetig, weil:
  - der Nexus (`nexus.guidecom.local`) mit selbstsigniertem Zertifikat oft nicht
    erreichbar ist (`PKIX path building failed`), und
  - sonst gegen **veraltete `~/.m2`-JARs** kompiliert wird -> Fehler wie
    `Symbol nicht gefunden: Klasse PersonalveraenderungAktionenBereich`.
- Steuerung ueber die Variable `+idea-build-dependencies` (Default `t`).
  Auf `nil` setzen (in `config.el`: `(setq +idea-build-dependencies nil)`) fuer den
  schnellen Pfad, wenn `~/.m2` bereits aktuell ist (dann nur
  `compile exec:java`).
- Nexus-Zertifikat: per `-Dmaven.resolver.transport=wagon` zusammen mit
  `-Dmaven.wagon.http.ssl.insecure=true` wird das Zertifikat ignoriert (Maven 3.9
  nutzt sonst den nativen Transport, fuer den die wagon-Flags nicht greifen).

### "Build before run" beim dap-Start (`SPC m r`)

> **STANDARD: AUS** (`+idea-build-before-run` = `nil`). `SPC m r` startet direkt, ohne
> Vor-Kompilierung. Grund: der Start lief sonst im `*compilation*`-Sentinel (nach dem
> Build) OHNE Java-Buffer-Kontext -> der Guard meldete faelschlich
> *"Kein JDT.LS in diesem Buffer aktiv"*. Wenn `target/classes` veraltet sind, vorher
> einmalig `SPC m c` (bzw. `mvn compile`) laufen lassen. Wer den automatischen Vor-Build
> trotzdem will: `(setq +idea-build-before-run t)` -- der Guard ist inzwischen
> buffer-unabhaengig repariert.

Optionaler Vor-Build (wenn aktiviert) -- wie IntelliJs "Build before run":

```
mvn -Pent-dev -pl <modul> -am -Dmaven.test.skip=true compile
```

- Warum noetig: dap-java startet mit dem von **JDT.LS aufgeloesten Classpath**. Fuer
  Reactor-Geschwister-Module zeigt der auf deren **`target/classes`** (nicht auf
  `~/.m2`). Sind die nicht/veraltet kompiliert, kommt zur Laufzeit ein
  `NoClassDefFoundError` / `ClassNotFoundException` (z.B. `ApiEntscheidungAnhang`),
  obwohl der Code in Emacs fehlerfrei aussieht. Der Vor-Build frischt genau diese
  `target/classes` auf (Modul **+** Upstream-Module via `-am`).
- Der Build laeuft im `*compilation*`-Buffer; **nur bei Erfolg** startet der Run --
  bei Compile-Fehlern wird der Start abgebrochen und die Fehler werden angezeigt
  (wie in IntelliJ).
- Steuerung ueber `+idea-build-before-run` (Default **`nil`** = aus). Zum Aktivieren:
  `(setq +idea-build-before-run t)` in `config.el`.
- Unterschied zum mvn-Weg (`SPC m R`): dort wird `install` (`-am`) nach `~/.m2`
  gebaut (`+idea-build-dependencies`); der dap-Weg braucht nur `compile`
  (`target/classes`), das ist schneller.
- Reicht `-am` mal nicht (z.B. eine nur per Reflection genutzte Klasse aus einem
  Nicht-Compile-Abhaengigkeitsmodul), einmalig den ganzen Reactor bauen:
  `SPC m m C` (clean install) bzw. `SPC m m c` (compile).

## An laufende JVM andocken (Remote-Debug)

- `SPC m a` -> `+idea/attach` (bzw. dap-Template "ENT attach :5005")
- Ablauf: App mit `SPC m R` + Debug starten -> warten bis Jetty laeuft ->
  `SPC m a` zum Andocken.

## Debugger-Bedienung (dap-mode) -- alle Shortcuts unter `SPC d`

Das komplette Debugging laeuft ueber **dap-mode**. Der `SPC d`-Prefix ist auf die
passenden `dap-mode`-Befehle gelegt (Dooms Default zeigte auf das andere Paket `dape`,
das hier NICHT verwendet wird -- die `dape`-Tasten haetten nicht zur laufenden Session
gepasst). IntelliJ-Aequivalente in Klammern.

### Session starten/stoppen

| Taste | Befehl | Wirkung |
|-------|--------|---------|
| `SPC d d` | `dap-debug` | Debug ueber ein **Template** starten |
| `SPC d R` | `+idea/run` | **Run-Config-Picker** (aus `.idea/runConfigurations`), Run/Debug |
| `SPC d L` | `dap-debug-last` | letzten Debug-Lauf **erneut** starten |
| `SPC d q` | `dap-disconnect` | aktuelle Session **trennen/beenden** |
| `SPC d Q` | `+idea/stop-run` | **alles** stoppen (dap-Sessions + mvn-Compilation) |

> Hinweis: Der uebliche Einstieg bleibt `SPC m r` (Run-Config-Picker -> Run/Debug).
> `SPC d` ist die **Steuerung waehrend** der Session.

### Ausfuehrung steuern (im Halt am Breakpoint)

| Taste | Befehl | IntelliJ |
|-------|--------|----------|
| `SPC d c` | `dap-continue` | **Resume** (F9) |
| `SPC d n` | `dap-next` | **Step Over** (F8) |
| `SPC d i` | `dap-step-in` | **Step Into** (F7) |
| `SPC d o` | `dap-step-out` | **Step Out** (Shift+F8) |
| `SPC d h` | `dap-hydra` | **Steuer-Panel** (Transient mit allen Tasten in einem) |

Tipp: `SPC d h` (dap-hydra) oeffnet ein Panel, in dem `n`/`i`/`o`/`c` etc. als
**Einzeltasten** wirken -- am schnellsten zum Durchsteppen. Zusaetzlich blendet sich
am Breakpoint automatisch die schwebende Toolbar ein (nur GUI, siehe unten).

### Breakpoints

| Taste | Befehl | Wirkung |
|-------|--------|---------|
| `SPC d b` | `dap-breakpoint-toggle` | Breakpoint **setzen/entfernen** (Ctrl+F8) |
| `SPC d B` | `dap-breakpoint-delete-all` | **alle** Breakpoints loeschen |
| `SPC d C` | `dap-breakpoint-condition` | **bedingter** Breakpoint (nur bei Bedingung stoppen) |
| `SPC d l` | `dap-breakpoint-log-message` | **Logpoint** (loggt, statt zu stoppen) |
| `SPC d H` | `dap-breakpoint-hit-condition` | Stop erst nach n **Treffern** |

### Werte inspizieren

| Taste | Befehl | Wirkung |
|-------|--------|---------|
| `SPC d e` | `dap-eval-thing-at-point` | Ausdruck **unter dem Cursor** auswerten |
| `SPC d E` | `dap-eval` | freien **Ausdruck eingeben** und auswerten |
| `SPC d w` | `dap-ui-expressions-add` | Ausdruck als **Watch** hinzufuegen |
| `SPC d r` | `dap-ui-repl` | interaktive **REPL** |

### Fenster/Panels & Navigation

| Taste | Befehl | Wirkung |
|-------|--------|---------|
| `SPC d v` | `dap-ui-locals` | **Locals/Variablen** |
| `SPC d x` | `dap-ui-expressions` | **Watches**-Fenster |
| `SPC d k` | `dap-ui-breakpoints` | **Breakpoint-Liste** |
| `SPC d s` | `dap-ui-sessions` | laufende **Sessions** |
| `SPC d f` | `dap-switch-stack-frame` | **Stack-Frame** wechseln |
| `SPC d t` | `dap-switch-thread` | **Thread** wechseln |

Wichtig: Vor einem Debug-Lauf das Projekt bzw. Modul kompilieren (`SPC m m c`
bzw. `mc`). Der `mvn exec:java`-Weg kompiliert selbst
(`compile exec:java`, kompiliert Hauptcode + kopiert Ressourcen inkl. `ent-dev`-conf).

### Debug-Toolbar (dap-ui-controls) nur am Breakpoint

Die schwebende Steuerungs-Leiste (Step Over/Into/Out, Continue, Stop) wird -- wie in
IntelliJ -- **nur eingeblendet, wenn die Ausfuehrung an einem Breakpoint steht** (bzw.
nach einem Step). Beim Weiterlaufen (`Continue`) und beim Session-Ende verschwindet sie
automatisch wieder.

Umgesetzt in `+java.el`:
- `controls` wird aus `dap-auto-configure-features` entfernt (kein Dauer-Einblenden ueber
  die ganze Session).
- `dap-stopped-hook` -> Toolbar an (`dap-ui-controls-mode 1`),
  `dap-continue-hook`/`dap-terminated-hook` -> Toolbar aus.

Hinweis: Die Toolbar ist eine `posframe` und funktioniert daher nur im **GUI-Emacs**,
nicht im Terminal (`et`).

### HotSwap: Änderungen ohne Neustart übernehmen (SPC m h)

Wie IntelliJ ("Reload Changed Classes") können geänderte Klassen **in die laufende
Debug-Session** geladen werden, ohne komplett neu zu bauen oder neu zu starten.

- **Nicht bei jedem Save**: `dap-java-hot-reload` steht auf `never` -- Speichern allein
  lädt nichts in die JVM. So kann man erst mehrere Changes machen.
- **Auf Zuruf**: `SPC m h` (oder global `SPC r h`) -> `+java/hotswap`. Speichert die
  geänderten Java-Buffer, lässt JDT.LS inkrementell kompilieren und schiebt dann
  **einmalig** die geänderten Klassen per JDWP in die laufende JVM.
- Voraussetzung: eine **laufende Debug-Session** (`SPC m r` -> Debug bzw.
  `SPC m R` + Debug und `SPC m a` zum Andocken).

**Grenzen** (identisch zu IntelliJ, JVM-HotSwap-Limit): Es lassen sich nur
**Methoden-Körper** ersetzen. Neue/entfernte Methoden oder Felder, geänderte
Signaturen oder die Klassenhierarchie erfordern einen Neustart (`SPC m e`). In dem Fall
meldet die JVM "changed classes" nicht als reloadbar; dann einfach rerun.

## Java-Tests: Test-Runner-Jar (`SPC m T a` / `t`)

Java-Tests laufen über `dap-java`, das intern
`java -jar <junit-platform-console-standalone.jar> -c/-m <Test>` aufruft. Diese Jar
ist **nicht** mit `dap-java` gebündelt. Fehlt sie, bricht der Debug-Adapter ab mit:

```
Error: Unable to access jarfile .../eclipse.jdt.ls/test-runner/junit-platform-console-standalone.jar
Debug Adapter exited abnormally with code 1
```

**Fix (automatisch):** `+java.el` enthält `+dap-java--ensure-test-runner` (im
`after! dap-java`-Block). Beim Start wird geprüft, ob die Jar am erwarteten Pfad
liegt; falls nicht, wird die neueste `junit-platform-console-standalone-*.jar` aus
`~/.m2` dorthin kopiert (Maven zieht sie ohnehin als Test-Abhängigkeit). Es ist also
kein Download nötig, solange das Projekt einmal per Maven gebaut wurde.

Hinweis: Die Testklassen müssen **kompiliert** sein (`target/test-classes`), sonst
`ClassNotFound`. Vorher ggf. `SPC m c` (Projekt prüfen/kompilieren) oder Maven bauen.
