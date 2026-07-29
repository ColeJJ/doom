# Git, GitLab (Forge), Worktrees & Pre-Commit

## Magit (vorhanden)

- Status: `SPC g g`
- Blame/Annotate: `SPC g B` (inline im Buffer) bzw. `SPC g A` (separate Ansicht), Time-Machine: `SPC g t`, Datei im Browser: `SPC g o`
- Diff in der Fringe (diff-hl/vc-gutter) ist aktiv.

## Branch-Diff gegen den Abzweigpunkt (`SPC g d`)

**`SPC g d`** -> `+git/diff-vs-base-branch`: zeigt **alles, was auf dem aktuellen Branch
seit dem Abzweig passiert ist** -- also den Diff gegen `develop` bzw. `master`/`main`.
Entspricht IntelliJ **"Compare with Branch"** bzw. `git diff develop...HEAD`.

- ohne Prefix: nur **committete** Aenderungen des Branches (Bereich `BASIS...HEAD`)
- `C-u SPC g d`: Basis-Branch **selbst waehlen** (der erkannte ist Default)
- `C-u C-u SPC g d`: Diff des **Arbeitsbaums** gegen den Abzweigpunkt, also inklusive
  ungestagter/ungecommitteter Aenderungen

Navigation im Diff-Buffer wie ueberall in Magit: `n`/`p` (Hunk), `TAB` (auf-/zuklappen),
`RET` springt an die Stelle in der Datei, `q` schliesst.

### Wie der Ursprungs-Branch erkannt wird

Git speichert **nicht**, von welchem Branch abgezweigt wurde -- diese Information existiert
nach dem `git checkout -b` nirgends mehr. Sie wird deshalb ueber den Merge-Base
rekonstruiert: fuer jeden Kandidaten aus `+git-base-branches` (Default `develop`, `master`,
`main`; lokaler Branch bevorzugt, sonst `origin/...`) wird `git merge-base` gegen `HEAD`
bestimmt, und es gewinnt der Kandidat mit dem **juengsten** Merge-Base -- also der
naechstliegende Abzweigpunkt. Bei einem Feature-Branch von `develop` ist das zuverlaessig
`develop`, obwohl `master` als weiter zurueckliegender Vorfahre ebenfalls "passen" wuerde.
Der aktuelle Branch selbst wird als Kandidat ausgelassen.

Weitere Basis-Branch-Namen (z.B. `release`) lassen sich per `+git-base-branches` ergaenzen.

## Datei-/Klassen-Historie (wie Telescope `git_bufcommits`)

Um die Aenderungen an der aktuellen Datei Commit fuer Commit visuell durchzugehen:

- **`SPC g D`** -> `magit-diff-buffer-file`: zeigt den **Diff der aktuellen Datei
  gegen HEAD** (den letzten Commit) -- also deine noch nicht committeten Aenderungen --
  in einem farbigen **Magit-Diff-Buffer** (Side-Buffer, wie die Commit-Ansicht).
  Navigation: `n`/`p` (Hunk), `TAB` (Hunk auf-/zuklappen), `RET` springt an die Stelle
  in der Datei, `q` schliesst. Fuer die **inline**-Variante direkt im Datei-Buffer (wie
  git blame) gibt es die Fringe-Marker von `diff-hl` + `SPC g v` (Hunk-Popup, siehe
  Abschnitt Git-Gutter).
- **`SPC g h`** -> `+git/file-history`: **Telescope-artiger Commit-Picker** mit
  **Live-Diff-Vorschau**. Listet alle Commits, die die aktuelle Datei geaendert haben
  (neueste zuerst, mit Hash/Datum/Autor/Betreff). Waehrend man durch die Liste
  blaettert, zeigt die Vorschau live den Diff **genau dieser Datei** im jeweiligen
  Commit (`git show <hash> -- FILE`, farbig im `diff-mode`). `RET` laesst den
  Diff-Buffer offen, damit man die Aenderung in Ruhe anschauen kann. Umbenennungen
  werden bei der Auflistung via `--follow` mitgenommen (der Diff bezieht sich auf den
  aktuellen Pfad -- vor einer Umbenennung kann er leer sein, es kommt dann ein Hinweis).
- **`SPC g H`** -> `git-timemachine`: blaettert die Datei-**Versionen** schrittweise
  durch (`n` = aelter, `p` = neuer, `q` = Ende) -- man sieht den Datei-Inhalt zum
  jeweiligen Commit statt des Diffs.
- **`SPC g L`** -> `magit-log-buffer-file`: native **Magit-Datei-Historie**; `RET` auf
  einem Commit zeigt den vollstaendigen Commit (alle Dateien) mit Magit-Navigation.

## Cherry-Pick: Commits aus einer Parent-Branch in die aktuelle holen

Ziel: einzelne (ausgewaehlte) Commits aus einer anderen Branch (z.B.
`origin/maintenance/14.7.2-x`) in die **aktuell ausgecheckte** Branch uebernehmen.
Das cherry-pickt jeden gewaehlten Commit als **neuen Commit** auf deinen HEAD.

> Wichtig: Vorher auf die **Ziel-Branch** wechseln (die, in die gepickt werden soll).
> Kontrolle im Status (`SPC g g`): oben bei `Head:` muss die Ziel-Branch stehen.
> Arbeitsverzeichnis sollte sauber sein (sonst erst committen/stashen, `SPC g g` -> `z z`).

### Variante A -- Commits im Log der Parent-Branch visuell auswaehlen (empfohlen)

1. `SPC g g` -> Magit-Status (HEAD = Ziel-Branch pruefen).
2. `l o` (`magit-log-other`) -> Parent-Branch/Revision eingeben, z.B.
   `origin/maintenance/14.7.2-x`. Es oeffnet sich deren Commit-Log.
3. Im Log die Commits auswaehlen:
   - **Ein Commit:** Cursor auf den Commit, dann `A A` (Pick = `magit-cherry-copy`).
   - **Mehrere Commits:** Region markieren -- in evil mit `V` (visual-line) ueber die
     gewuenschten Commits ziehen (oder `C-SPC` Mark setzen und mit `j`/`k` erweitern) --
     dann `A A`. Magit picked alle markierten Commits, **aeltester zuerst**.
4. `RET` auf einem Commit oeffnet vorher den Diff -- so siehst du, was du pickst.

### Variante B -- Commit(s) direkt per Hash/Ref

1. `SPC g g` (auf Ziel-Branch).
2. `A A` -> Magit fragt nach dem Commit -> Hash (z.B. `e83448d`), Ref oder Ausdruck
   wie `origin/master~2` eingeben. Ein Bereich `<alt>..<neu>` picked mehrere.

### Das `A`-Menue (Cherry-Pick-Transient) im Ueberblick

| Taste | Befehl | Wirkung |
|-------|--------|---------|
| `A A` | `magit-cherry-copy`   | **Pick** -- Commit(s) als neue Commits uebernehmen (`git cherry-pick`) |
| `A a` | `magit-cherry-apply`  | **Apply** -- Aenderungen nur in Working-Tree/Index, **ohne** eigenen Commit (`-n`) |
| `A h` | `magit-cherry-harvest`| Commit(s) hierher holen **und** in der Quell-Branch entfernen |
| `A d` | `magit-cherry-donate` | Commit(s) an eine andere Branch abgeben (aus HEAD entfernen) |
| `A n`/`A s` | Spinout / Spinoff | Commit(s) in eine neue Branch aus-/abzweigen |

### Konflikte / Sequenz steuern

Stoppt der Cherry-Pick wegen eines Konflikts:
1. Konflikte in den betroffenen Dateien loesen.
2. Im Status (`SPC g g`) die geloesten Dateien stagen (`s`).
3. `A` oeffnen -> **continue** fortsetzt, **skip** ueberspringt diesen Commit,
   **abort** bricht die gesamte Sequenz ab (macht bereits Gepicktes rueckgaengig).

### Tipp: passende Commits finden

`Y` (`magit-cherry`) im Status vergleicht zwei Branches und listet die Commits, die in
der Parent-Branch, aber **noch nicht** in HEAD sind -- ideal, um zu sehen, was ueberhaupt
zum Picken infrage kommt. Von dort aus ebenfalls mit `A A` pickbar.

## Diff-Darstellung wie in IntelliJ

- **Syntax-Highlighting / Theme-Farben im Diff:** ueber `magit-delta` (leitet die
  Diffs durch das CLI-Tool [`delta`](https://github.com/dandavison/delta)). Statt nur
  rot/gruen wird der Code mit Sprach-Syntax eingefaerbt. Installiert via
  `brew install git-delta`; in [`+git.el`](../+git.el) aktiviert (nur wenn `delta`
  im PATH ist). Dunkles Syntax-Theme wird automatisch passend zum Hintergrund gewaehlt.
- **Wort-genaues Diff:** `magit-diff-refine-hunk 'all` hebt die geaenderten Stellen
  innerhalb einer Zeile hervor (wie IntelliJ).

### Warnungen vor dem Commit (z.B. unused imports)

Magit zeigt **keine** Lint-Marker direkt im Diff (das ist eine IntelliJ-Commit-Dialog-
Funktion ohne 1:1-Pendant). Stattdessen mehrgleisig abgesichert:

1. **Im Buffer sichtbar:** JDT.LS/flycheck markieren Warnungen (unused imports,
   ungenutzte Variablen ...) direkt im Code -- inline am Zeilenende (`lsp-ui-sideline`,
   bleibt fuer Diagnostics an) und in der Fringe. LSP-Diagnosen dieser Datei: `SPC c x`;
   die Gesamtliste des Projekts/Workspaces: `SPC c X`.
2. **Automatisch beim Speichern:** `lsp-java-save-actions-organize-imports` entfernt
   ungenutzte Imports beim Speichern -- so landen sie gar nicht erst im Commit.
3. **Pre-Commit-Hook:** kompiliert die betroffenen Module (siehe unten) und stoppt
   den Commit bei Build-Fehlern.

## GitLab (Forge) -- self-hosted

`forge` ist aktiv (`(magit +forge)`) und kennt `gitlab.guidecom.local`
(siehe [`+git.el`](../+git.el)). Token in `~/.authinfo(.gpg)`:

```
machine gitlab.guidecom.local/api/v4 login <user>^forge password <token>
```

Danach im Repo: `M-x forge-pull` (Issues/MRs laden), Forge-Dispatch `SPC g '`.
MRs/Issues anlegen/anzeigen ueber das Forge-Menue.

## Worktrees

- `SPC g w` -> `magit-worktree` (Transient), oder `Z` im Magit-Status:
  - `Z b` neue Worktree + Branch
  - `Z c` Worktree auschecken
  - `Z g` zu einer Worktree wechseln
- `magit-todos-mode` zeigt TODO/FIXME im Magit-Status.

## Pre-Commit-Hook (Code-Analyse vor dem Commit)

Schnelle Absicherung: kompiliert nur die betroffenen Maven-Module (kein fremder
Formatter, damit der IntelliJ/JDT-Style erhalten bleibt). Die fertige Datei liegt
unter [`docs/git-hooks/pre-commit`](git-hooks/pre-commit).

Installation im Projekt-Repo (einmalig, von dir bewusst auszufuehren):

```sh
cd ~/IdeaProjects/entscheidungen
mkdir -p .githooks
cp ~/.config/doom/docs/git-hooks/pre-commit .githooks/pre-commit
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks   # wird von allen Worktrees geteilt
```

- Magit fuehrt den Hook beim Commit automatisch aus.
- Im Einzelfall ueberspringen: `SKIP_MVN=1 git commit ...` oder `git commit --no-verify`.

Hinweis: Direkte Schreibzugriffe ins `entscheidungen`-Repo wurden in dieser
Einrichtung absichtlich nicht vorgenommen; bitte obige Schritte manuell ausfuehren.

## Git-Gutter (diff-hl) -- wie IntelliJ/VSCode

Am linken Fringe zeigen farbige Balken die noch nicht committeten Aenderungen relativ
zu HEAD -- **live beim Tippen** (Dooms `vc-gutter +pretty` via `diff-hl`, `flydiff`):
gruen = hinzugefuegt, gelb/orange = geaendert, rot = geloescht.

Interaktion (IntelliJ-artig):

| Taste / Aktion | Wirkung |
|----------------|---------|
| **Klick auf den Fringe-Marker** | Popup mit der Aenderung + Buttons (verwerfen/stagen/kopieren/naechster) |
| `SPC g v` | Hunk unter dem Cursor als **Popup** anzeigen (`diff-hl-show-hunk`) |
| `] d` / `[ d` | zum **naechsten/vorherigen** Hunk springen (auch `SPC g ]` / `SPC g [`) |
| `SPC g r` | Hunk **verwerfen** (Rollback, `+vc-gutter/save-and-revert-hunk`) |
| `SPC g S` | Hunk/Datei **stagen** (`magit-file-stage`) |

Ist schon out-of-the-box aktiv (`global-diff-hl-mode`); die Klick-/Popup-Extras kommen
aus [`+git.el`](../+git.el) (`global-diff-hl-show-hunk-mouse-mode` + `SPC g v`).

## eDiff: an der Stelle editieren

Innerhalb einer eDiff-Sitzung kannst du die verglichenen Buffer **direkt editieren**:

- **Direkt reinklicken**: mit der Maus (oder `C-x o`) ins gewuenschte Fenster
  wechseln und normal tippen. eDiff erlaubt das Editieren der Variant-Buffer
  jederzeit. Nach den Aenderungen im eDiff-Steuerfenster **`!`** druecken -> die
  Diffs werden neu berechnet.
- **`E` (Shortcut im Steuerfenster)** -> `+ediff/edit-mine`: springt von der
  aktuellen Diff-Stelle direkt in den **eigenen** Buffer (bei 3-Wege = `C`,
  Working-Tree/rechts; sonst `B`) und setzt den Cursor genau auf die Aenderung.
- **Zurueck ins Steuerfenster** (wo `n`/`p` etc. wirken): `C-x o` (Fenster wechseln,
  Setup ist `plain` = ein Frame) **oder** `C-c e` -> `+ediff/goto-control` als
  direkter Sprung ins `*Ediff Control Panel*` (wirkt auch im Insert-State).
  Danach `!` zum Neuberechnen der Diffs.

> Merke: `n`/`p` = naechste/vorherige Aenderung, `a`/`b` = Seite kopieren,
> `!` = Diffs neu berechnen, `E` = ins eigene Buffer springen/editieren, `C-x o`/`C-c e` = zurueck ins Steuerfenster, `q` = Ende.


## Blame / Annotate wie IntelliJ

Zwei Varianten:

### `SPC g B` – Inline im selben Buffer (Standard, wie IntelliJ Annotate)

Blendet Commit-Kürzel, Autor und Datum je Zeile in der **linken Margin des aktuellen
Puffers** ein – kein separater Buffer, das **Syntax-Highlighting des Codes bleibt
erhalten**. Die Margin ist **nach Alter eingefärbt** (frisch = rot/orange … alt =
blau/violett; Verlauf via `+git-blame-age-colors` in `+git.el`). Während der Ansicht
ist der Puffer schreibgeschützt.

| Taste | Wirkung |
|-------|---------|
| `RET` | Commit-Diff der aktuellen Zeile ansehen (die Änderung) |
| `q` bzw. erneut `SPC g B` | Inline-Blame wieder ausschalten (Puffer wieder editierbar) |

Nicht committete Zeilen erscheinen als `••••••• (lokal)`.

### `SPC g A` – Separate Ansicht (`vc-annotate`)

Öffnet die klassische `vc-annotate`-Ansicht in einem eigenen Buffer (färbt den
Code-Text nach Alter). Dort: `RET`/`d` = Diff der Zeile, `D` = Changeset-Diff,
`l` = Log, `a` = weiter in die Historie, `q` = schließen.

Für den *inline*-Blick auf reine Zeilenänderungen (ohne Blame) bleiben zusätzlich
die `diff-hl`-Fringe-Marker + `SPC g v` (Hunk-Popup).
