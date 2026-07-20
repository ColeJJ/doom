;;; +git.el -*- lexical-binding: t; -*-
;;
;; Git/Worktree/GitLab-Erweiterungen fuer Doom. Geladen via (load! "+git") aus config.el.
;; Dokumentation: siehe docs/git.md.

;; self-hosted GitLab bei forge bekanntmachen (Host . API . ID . Repository-Klasse):
;; Voraussetzung: Token in ~/.authinfo(.gpg):
;;   machine gitlab.guidecom.local/api/v4 login <user>^forge password <token>
(after! forge
  (add-to-list 'forge-alist
               '("gitlab.guidecom.local"
                 "gitlab.guidecom.local/api/v4"
                 "gitlab.guidecom.local"
                 forge-gitlab-repository)))

;; TODO/FIXME-Uebersicht direkt im Magit-Status anzeigen:
(after! magit
  (magit-todos-mode 1)
  ;; Wort-genaues Diff (IntelliJ: hebt die geaenderten Stellen INNERHALB der Zeile hervor):
  (setq magit-diff-refine-hunk 'all))

;; Syntax-Highlighting + Theme-Farben im Magit-Diff (IntelliJ-aehnlich).
;; magit-delta leitet die Diffs durch das CLI-Tool "delta" (brew install git-delta),
;; das den Code mit Syntax-Highlighting einfaerbt -- so "dringen" Sprach-/Theme-Farben
;; durch statt nur rot/gruen. Nur aktivieren, wenn "delta" installiert ist (sonst Fehler).
(when (executable-find "delta")
  (after! magit
    (require 'magit-delta)
    ;; --true-color always => kraeftige Theme-Farben auch im GUI-Emacs.
    ;; --color-only behaelt das Magit-Layout bei und faerbt nur den Code ein.
    ;; Kein --dark/--syntax-theme setzen: magit-delta erkennt den dunklen Hintergrund
    ;; automatisch und waehlt `magit-delta-default-dark-theme' (Monokai Extended).
    (setq magit-delta-delta-args
          '("--max-line-distance" "0.6" "--true-color" "always" "--color-only"))
    (magit-delta-mode 1)))

;; Worktree-Schnellzugriff (entspricht 'Z' im Magit-Status):
;;   Z b  neue Worktree + Branch | Z g  zu Worktree wechseln | Z c  Worktree auschecken
(map! :leader :desc "Git Worktree" "g w" #'magit-worktree)

(provide '+git)
;;; +git.el ends here
