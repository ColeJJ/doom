# Git, GitLab (Forge), Worktrees & Pre-Commit

## Magit (vorhanden)

- Status: `SPC g g`
- Blame: `SPC g B`, Time-Machine: `SPC g t`, Datei im Browser: `SPC g o`
- Diff in der Fringe (diff-hl/vc-gutter) ist aktiv.

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
   bleibt fuer Diagnostics an) und in der Fringe. Gesamtliste: `SPC c x`
   (`flycheck-list-errors`) bzw. `M-x lsp-treemacs-errors-list`.
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
