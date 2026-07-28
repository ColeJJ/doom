# Performance: schnell wie neovim

Ziel: Dateien (Java/Org) in **Millisekunden** statt Sekunden oeffnen. Zwei Hebel
sind entscheidend -- **native-compilation** und der **Daemon**.

Gemessenes Ergebnis nach der Umstellung (warmer Daemon, native-comp fertig):

| Aktion                 | vorher        | nachher   |
|------------------------|---------------|-----------|
| Org-Datei oeffnen      | ~2 s+         | **0,02 s**|
| Elisp-Datei oeffnen    | ~2 s+         | **0,06 s**|

## 1. native-compilation (groesster Faktor)

Die urspruengliche `/Applications/Emacs.app` (offizieller GNU-NS-Build von
emacsformacosx) war **ohne** native-comp gebaut. Ergebnis: der gesamte Elisp-Code
(Org, LSP, Redisplay, Corfu, Magit ...) lief nur byte-compiled -- real **2-4x
langsamer**. Doom ist explizit fuer native-comp ausgelegt.

**Fix:** `emacs-plus@30` mit native-comp via Homebrew (bereits installiert):

```sh
brew tap d12frosted/emacs-plus
brew install emacs-plus@30            # native-comp (=aot) ist hier Standard
```

### Stolperstein: der emacs-plus-`bin/emacs`-Wrapper (WICHTIG)

`emacs-plus` legt als `/opt/homebrew/bin/emacs` **kein** Binary an, sondern ein
kleines Wrapper-Skript. Das sucht die App in dieser Reihenfolge:

1. `/Applications/Emacs.app`  <-- war noch die ALTE Build ohne native-comp!
2. `~/Applications/Emacs.app`
3. `/opt/homebrew/Cellar/emacs-plus@30/.../Emacs.app`

Da die alte `/Applications/Emacs.app` existierte, startete der Wrapper immer die
**alte** Build -> `native-comp-available-p` war `nil`. Deshalb ist `bin/emacs`
hier direkt auf das echte native-comp-Binary gebogen (Wrapper umgangen):

```sh
brew link --overwrite emacs-plus@30
ln -sf /opt/homebrew/opt/emacs-plus@30/Emacs.app/Contents/MacOS/Emacs \
       /opt/homebrew/bin/emacs
```

Pruefen (muss `t` liefern):

```sh
emacs --batch --eval '(princ (native-comp-available-p))'   # => t
```

Beim **ersten** Daemon-Start kompiliert Emacs alle Pakete einmalig nativ
(hier: 442 `.eln`-Dateien, dauert 1-2 Min im Hintergrund, spuerbare CPU-Last).
Danach dauerhaft schnell. `.eln`-Cache: `~/.config/emacs/.local/cache/eln/`.
In [`config.el`](../config.el) sind die Warnungen dieser Kompilierung auf `silent`
gestellt (`native-comp-async-report-warnings-errors`).

## 2. Daemon + emacsclient (statt Klick-Start)

Per Klick auf die App zahlst du bei **jeder** Datei die volle Doom-Ladezeit. Mit
Daemon laeuft Emacs **einmal** im Hintergrund; `emacsclient` oeffnet Dateien
praktisch instant.

**Bewusst NICHT via launchd / `brew services`:** ein so gestarteter Daemon erbt
deine Shell-Umgebung (`JAVA_HOME`, Maven, `PATH`) **nicht** -> LSP/Maven brechen.
Darum wird der Daemon aus der Shell gestartet (erbt die volle Umgebung). In
`~/.zshrc` steht dafuer:

```sh
# `e` ohne Argument -> neuer GUI-Frame im Doom-Startfenster (Dashboard, *doom*).
# `e datei ...`      -> oeffnet die Datei(en) im GUI-Frame.
e () {
  if [ $# -eq 0 ]; then
    emacsclient -c -n -a '' --eval '(+doom-dashboard/open (selected-frame))'
  else
    emacsclient -c -n -a '' "$@"
  fi
}
# `et` ohne Argument -> Doom-Startfenster (Dashboard) im AKTUELLEN Terminal (TUI);
# `et datei ...`      -> oeffnet die Datei(en) im Terminal (TUI).
et () {
  if [ $# -eq 0 ]; then
    emacsclient -t -a '' --eval '(+doom-dashboard/open (selected-frame))'
  else
    emacsclient -t -a '' "$@"
  fi
}
export EDITOR="emacsclient -t -a ''"     # git commit etc. im Terminal-Client
export VISUAL="$EDITOR"
# Daemon einmalig starten, falls keiner laeuft (mit voller Shell-Umgebung):
if ! emacsclient -e t >/dev/null 2>&1; then
  (emacs --daemon >/dev/null 2>&1 &)
fi
```

Oeffnen:

```sh
e                 # neuer GUI-Frame im Doom-Startfenster (Dashboard) -- wie gewohnt
e  datei.java     # Datei im GUI-Frame, nicht blockierend
et                # Doom-Startfenster (Dashboard) im AKTUELLEN Terminal (TUI)
et datei.org      # Datei im Terminal/TUI
```

Das `-a ''` startet notfalls automatisch einen Daemon, falls keiner laeuft. Das
Doom-Startfenster ist der Buffer `*doom*`; `+doom-dashboard/open` zeigt ihn im
neuen Frame an.

### Weiter per Klick starten?

Es gibt eine klickbare native-comp-App unter `~/Applications/Emacs.app`
(Symlink auf den emacs-plus-Build, ohne sudo angelegt). Sie startet aber eine
**frische Instanz**, nicht den Daemon.

Optional (empfohlen fuer den Dock-Workflow): die alte `/Applications/Emacs.app`
durch den native-comp-Build ersetzen. Das braucht **sudo** (macOS schuetzt
`/Applications`) und musst du selbst ausfuehren:

```sh
sudo mv /Applications/Emacs.app /Applications/Emacs-official-backup.app
sudo ln -s /opt/homebrew/opt/emacs-plus@30/Emacs.app /Applications/Emacs.app
```

Danach ist auch der geklickte Emacs native-comp. (Die alte Build bleibt als
Backup erhalten und kann geloescht werden, wenn alles laeuft.)

## 3. Config-seitige Optimierungen (bereits gesetzt)

In [`config.el`](../config.el) / [`+java.el`](../+java.el):

- `inhibit-compacting-font-caches t` -- verhindert das Langsamerwerden ueber die
  Sitzung (Font-Cache mit Icon-Fonts). Dazu `fast-but-imprecise-scrolling`,
  `redisplay-skip-fontification-on-input`, `idle-update-delay`, `jit-lock-defer-time`.
- GC entspannt: `gcmh-high-cons-threshold` = 256 MB.
- native-comp: Warnungen `silent`, JIT an, halbe CPU-Kerne fuer den Erstlauf.
- LSP weniger eifrig: `lsp-idle-delay 1.0`, Symbol-Highlighting/Breadcrumb/Modeline-
  Code-Actions/On-Type-Format aus, Datei-Watcher-Schwelle gesenkt. Code-Lens bei
  Bedarf mit `SPC m l` toggeln.

## Warum ist das erste Java-Datei-Oeffnen trotzdem kurz spuerbar?

Beim **ersten** Oeffnen einer `.java`-Datei pro Daemon-Sitzung verbindet sich
JDT.LS und indiziert das Projekt -- das ist einmalig. Jede weitere Datei ist dann
schnell. Solange der Daemon laeuft, bleibt der Server warm.

## Terminal sieht blau/falsch aus (iTerm2) -> True-Color

Symptom: Im GUI ist das Theme dunkel, im Terminal (`et`) wird der Hintergrund
**grellblau**. Ursache: `gruber-darker` nutzt als Hintergrund ein sehr dunkles
Marineblau (`#010611`). Ohne 24-bit-Farben rechnet das Terminal das auf die
naechste 256-Farbe herunter -- und weil der Blauanteil dominiert, landet es bei
einem sichtbaren Blau (Farbe 17) statt bei Fast-Schwarz.

Fix: **True-Color aktivieren.** Emacs 29+ schaltet 24-bit ein, wenn die Umgebungs-
variable `COLORTERM=truecolor` gesetzt ist (siehe `etc/NEWS.29`). In `~/.zshrc`
steht daher **vor** dem Daemon-Autostart:

```sh
export COLORTERM=truecolor
```

Wichtig: Der **Daemon** muss diese Variable in seiner Umgebung haben (Emacs liest
`COLORTERM` aus der Prozess-Umgebung, nicht pro Client-Frame). Deshalb steht der
`export` vor dem Daemon-Start. Nach der Aenderung einmal:

```sh
emacsclient -e '(kill-emacs)'   # alten Daemon beenden
# neues iTerm2-Fenster oeffnen -> Daemon startet mit COLORTERM=truecolor neu
et                              # jetzt dunkel wie im GUI
```

Pruefen im laufenden Daemon: `emacsclient -e '(getenv "COLORTERM")'` => `"truecolor"`.
iTerm2 kann 24-bit nativ darstellen; eine spezielle Terminfo (`xterm-direct`) ist
damit nicht noetig.

## Icons im Terminal (nerd-icons) fehlen (`?`-Kaestchen)

Doom nutzt **nerd-icons**; ohne passende Nerd-Font erscheinen nur `?`-Kaestchen
(im GUI und im Terminal). Fonts installieren:

```sh
brew install --cask font-symbols-only-nerd-font   # fuer GUI-Emacs (nerd-icons)
brew install --cask font-jetbrains-mono-nerd-font # fuer iTerm2 (Terminal-Icons)
```

- **GUI-Emacs**: findet "Symbols Nerd Font Mono" automatisch (ggf. Emacs/Daemon neu
  starten). Falls noetig: `M-x nerd-icons-install-fonts`.
- **iTerm2 (Terminal)**: die Icons rendern nur, wenn iTerm2 eine Nerd-Font nutzt.
  *Settings -> Profiles -> Text -> Font* auf **"JetBrainsMono Nerd Font"** stellen.

## Einheitlicher Hintergrund im Terminal (et)

Im GUI ist der Theme-Hintergrund `#010611`. Damit das Terminal nicht "zweifarbig"
wirkt (Emacs-Flaeche vs. iTerm2-Rand), uebernehmen **Terminal-Frames** den iTerm2-
Hintergrund: In [`config.el`](../config.el) setzt `+tty/inherit-terminal-background`
den `default`-Hintergrund fuer nicht-grafische Frames auf `unspecified-bg` (GUI
bleibt unveraendert). So ist die Flaeche einheitlich (auch bei iTerm2-Transparenz).

Fuer den **exakten** Theme-Look im Terminal zusaetzlich iTerm2s Hintergrund auf
`#010611` setzen: *Settings -> Profiles -> Colors -> Background* -> Hex `010611`.
Dann ist Terminal == GUI.

## Nach einem Emacs-Update (`brew upgrade emacs-plus@30`)

Der Wrapper-Fix an `bin/emacs` und `brew link` koennen zurueckgesetzt werden.
Dann erneut:

```sh
brew link --overwrite emacs-plus@30
ln -sf /opt/homebrew/opt/emacs-plus@30/Emacs.app/Contents/MacOS/Emacs /opt/homebrew/bin/emacs
~/.config/emacs/bin/doom sync
```

## Kurz-Check

```sh
emacs --batch --eval '(princ (native-comp-available-p))'   # t erwartet
emacsclient -e '(native-comp-available-p)'                 # t (Daemon laeuft)
find ~/.config/emacs/.local/cache/eln -name '*.eln' | wc -l  # > 0
```

## "Timeout while waiting for response. Method: textDocument/rangeFormatting"

**Symptom:** Beim Formatieren (`=` / `SPC c f`) kommt sporadisch der Timeout, obwohl
nur wenige Zeilen formatiert werden. 10 s sollten dafuer massig reichen.

**Ursache (nicht JDT!):** Der JDT-Server antwortet schnell (im `*lsp-log*` sind
Validierung/Reconcile bei 1-170 ms, der Java-Prozess liegt bei 0 % CPU). Das Problem
liegt auf der **Emacs-Seite (macOS-NS-Build)**: `lsp-format-region` schickt eine
*synchrone* Anfrage und wartet in `accept-process-output` -> `ns_select`. Dabei pumpt
Emacs den AppKit-Event-Loop. Fragt macOS in dem Moment intensiv die
**Accessibility/Fenster-API** ab (Stage Manager / Fenster-Tiling / a11y-Clients),
verbringt der Event-Loop die Zeit dort, statt die *laengst eingetroffene* JDT-Antwort
aus der Pipe zu lesen -> die synchrone Anfrage laeuft in den 10-s-Timeout.

Ein `sample <emacs-pid> 2` zeigte genau diesen Stack:
`evil-indent -> lsp-format-region -> lsp-request -> accept-process-output -> ns_select_1
-> NSApplication run -> NSAccessibility.../SkyLight run_query -> mach_msg`.
Kurzzeitig 98 % CPU (Burst), danach wieder `sleeping` (0-2 %).

**Warum trifft es Formatierung und nicht Completion?** Formatierung ist eine *synchrone*
`lsp-request`, die den Main-Thread blockiert. Completion/Diagnostics laufen asynchron
und scheitern nicht an einem einzelnen Timeout.

**Beguenstigend:** Ein sehr lang laufender Daemon (hier 26 h Uptime, Peak-Footprint
4,2 GB). Lange NS-Daemons sammeln diese AppKit/a11y-Latenz an.

### Fix / Vorgehen
1. **Daemon neu starten** (wichtigster Hebel, frischer NS-Zustand):
   ```sh
   emacsclient -e '(save-buffers-kill-emacs)'   # sichert & beendet, danach Autostart/neu oeffnen
   # oder hart:  pkill -x Emacs   (Vorsicht: ungesicherte Buffer!)
   ```
2. `lsp-response-timeout` bleibt bei **10 s** (Default) -- der Wert war nie das Problem.
3. Optional gegen Hintergrund-Last im Event-Loop: `lsp-modeline-code-actions-mode`
   feuert `textDocument/codeAction` in `post-command-hook` (im Log:
   "Cancelling textDocument/codeAction ... in hook post-command-hook"). Bei Bedarf
   abschaltbar (Code-Actions gibt es weiter per Shortcut).
4. Optional echter LSP-Perf-Boost: `lsp-use-plists` (Env `LSP_USE_PLISTS=true` beim
   Doom-Build) -- schnelleres Deserialisieren grosser LSP-Antworten.

### Schnell-Diagnose
```sh
ps ax -o pid,stat,%cpu,command | grep -i '[E]macs'   # CPU/Status des Daemons
sample <emacs-pid> 2                                   # Stacktrace: wo haengt der Main-Thread?
emacsclient -e '(emacs-uptime)'                        # lange Uptime? -> neu starten
```

## CPU-Bursts beim Editieren/Formatieren = Garbage Collection (Fix: lsp-use-plists)

**Beobachtung:** Beim Tippen/Formatieren/Indexieren springt die Emacs-CPU kurz hoch
(gemessen: 3 % -> 76 % -> 18 %). Ein `sample` zeigt als heisseste Emacs-Funktionen fast
ausschliesslich **GC**: `process_mark_stack`, `sweep_strings`, `sweep_conses`,
`cons_marked_p`. Im echten Leerlauf: **0 GCs**. Die Spitzen sind also **GC-Pausen**.

**Warum:** JDT liefert grosse JSON-Antworten (Completion, Code-Actions, Indexierung).
lsp-mode deserialisiert die per Default in **Hash-Tables** -> sehr viel kurzlebiger Muell
-> haeufige GC. Ueber eine lange Session waechst der Heap (Peak hier 4,2 GB) -> GC-Pausen
werden laenger -> eine Pause reisst irgendwann den 10-s-Format-Timeout -> "hilft nur
Daemon-Neustart". Auf dem macOS-NS-Build addiert sich der AppKit-Event-Loop dazu.

### Fix: `lsp-use-plists` (aktiviert)
lsp-mode kann Antworten als **Plists statt Hash-Tables** halten -> deutlich weniger
Allokationen/GC und weniger Speicher. Das ist die offizielle LSP-Perf-Empfehlung.
Wichtig: Der Wert wird zur **Compile-Zeit** in die lsp-Makros eingebacken. Also:

1. `~/.zshenv`: `export LSP_USE_PLISTS=true` (wird VOR `.zshrc` geladen -> der aus
   `.zshrc` gestartete Daemon erbt die Variable).
2. **Alle** lsp-abhaengigen Pakete konsistent neu kompilieren (sonst Format-Mismatch
   zwischen Plist-Daten und Hashtable-Zugriffs-Makros):
   ```sh
   LSP_USE_PLISTS=true ~/.config/emacs/bin/doom sync --rebuild
   ```
3. Veraltete **native** `.eln` der lsp/dap-Pakete loeschen (die byte-kompilierte `.elc`
   war frisch, die `.eln` aber vom alten Build ohne Plists -> Emacs wuerde die alte
   `.eln` laden). Der Source-Hash im `.eln`-Namen aendert sich NICHT durch die
   Env-Variable, daher manuell entfernen:
   ```sh
   find ~/.config/emacs/.local/cache/eln -type f \
     \( -name 'lsp-*.eln' -o -name 'dap-*.eln' -o -name 'consult-lsp-*.eln' \) -delete
   ```
4. Daemon **einmalig** neu starten (mit gesetzter Env-Variable):
   ```sh
   emacsclient -e '(progn (save-some-buffers t) (kill-emacs))'
   LSP_USE_PLISTS=true emacs --daemon
   ```

**Verifizieren:**
```sh
emacsclient -e '(progn (require (quote lsp-mode)) (list (getenv "LSP_USE_PLISTS") lsp-use-plists))'
# -> ("true" "true")
```

Danach werden die lsp/dap-`.eln` beim ersten echten Einsatz im Hintergrund neu (mit
Plists) erzeugt; bis dahin laeuft die frische Plists-`.elc`. Kein wiederkehrender
Daemon-Neustart mehr noetig.

### Optional zusaetzlich (ohne Neustart)
- `lsp-modeline-code-actions-enable nil` in `+java.el`: die Lightbulb feuert
  `textDocument/codeAction` bei JEDEM Kommando (im `*lsp-log*`: "Cancelling
  textDocument/codeAction ... in hook post-command-hook"). Aus = weniger Requests/Muell;
  Code-Actions bleiben on-demand per `SPC c a`.
