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
alias et="emacsclient -t -a ''"          # Datei im Terminal (TUI)
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
et datei.org      # Terminal/TUI
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
