# Git, GitLab (Forge), Worktrees & Pre-Commit

## Magit (vorhanden)

- Status: `SPC g g`
- Blame: `SPC g B`, Time-Machine: `SPC g t`, Datei im Browser: `SPC g o`
- Diff in der Fringe (diff-hl/vc-gutter) ist aktiv.

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
