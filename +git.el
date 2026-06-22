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
  (magit-todos-mode 1))

;; Worktree-Schnellzugriff (entspricht 'Z' im Magit-Status):
;;   Z b  neue Worktree + Branch | Z g  zu Worktree wechseln | Z c  Worktree auschecken
(map! :leader :desc "Git Worktree" "g w" #'magit-worktree)

(provide '+git)
;;; +git.el ends here
