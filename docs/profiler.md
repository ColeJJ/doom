# Profiler (Memory & Methodenlaufzeiten)

Entspricht dem IntelliJ-Profiler (intern async-profiler + JFR). Ergebnisse werden
als interaktiver Flamegraph in Emacs angezeigt.

## Voraussetzung

```sh
brew install async-profiler   # stellt 'asprof' bereit
```

## Bedienung

- `SPC m P c` -> `+profiler/cpu`   : CPU-/Methodenlaufzeit-Profil
- `SPC m P m` -> `+profiler/alloc` : Memory-/Allokations-Profil

Ablauf je Befehl:
1. laufende JVM auswaehlen (`jps -l`, wie IntelliJ "Attach")
2. Dauer in Sekunden angeben (Default 30)
3. async-profiler laeuft im Hintergrund; danach oeffnet sich automatisch ein
   interaktiver Flamegraph-Buffer (`flamegraph`) mit Zoom und Sprung in den Quellcode.

Die Profile werden als "folded stacks" (`asprof -o collapsed`) erzeugt und von
`flamegraph-find-profile` gerendert. Alternativ HTML-Flamegraph:
`asprof -d 30 -f /tmp/flame.html <pid>` und im Browser oeffnen.

## JFR / JDK Mission Control (tiefe Heap-Analysen)

- Aufnahme beim Start (Run-Config VM-Args):
  `-XX:StartFlightRecording=duration=60s,filename=app.jfr`
- Live an laufender JVM: `jcmd <pid> JFR.start` / `jcmd <pid> JFR.dump filename=app.jfr`
- Analyse in JDK Mission Control (`brew install --cask jdk-mission-control`).

## Einordnung

Methoden-Hotspots und Allokationen sind voll abgedeckt (inkl. Quellcode-Sprung).
Ein vollstaendig nativer "Profiler-Tab" wie in IntelliJ existiert in Emacs nicht;
fuer Retention-/Heap-Detailanalysen dient JFR + JDK Mission Control.
