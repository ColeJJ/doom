;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; Theme direkt und reproduzierbar beim Start laden.
;; Hintergrund: Nur `doom-theme' zu setzen reichte hier nicht zuverlaessig; nach
;; `SPC h r r' war das Theme da, beim frischen Start aber nicht. Deshalb registrieren
;; wir den lokalen Theme-Ordner explizit und laden das Theme sofort aus DOOMDIR/themes.
;; `custom-safe-themes' verhindert Sicherheits-Prompts, falls der lokale Theme-Hash
;; nach eigenen Anpassungen nicht mehr zum alten Eintrag in custom.el passt.
(add-to-list 'custom-theme-load-path (expand-file-name "themes/" doom-user-dir))
(setq custom-safe-themes t
      ;; Standard-Theme beim Start. Zum dauerhaften Wechsel hier auf 'rose-pine-moon
      ;; aendern (und die load-theme-Zeile unten entsprechend) -- oder zur Laufzeit
      ;; einfach `SPC h t' benutzen (siehe +theme/load unten).
      doom-theme 'tj)
(load-theme 'tj t)

;; Sauberer Theme-Wechsel zur Laufzeit (auf `SPC h t').
;; `load-theme' allein deaktiviert das alte Theme NICHT -> Face-Reste (z.B. gruber-BG)
;; koennen unter dem neuen Theme durchscheinen. Deshalb erst alle aktiven Themes
;; deaktivieren, dann das gewaehlte laden. Verfuegbar sind alle Themes aus
;; `custom-theme-load-path' -- also auch das lokale `rose-pine-moon'.
(defun +theme/load (theme)
  "THEME sauber laden: erst alle aktiven Themes deaktivieren, dann THEME aktivieren."
  (interactive
   (list (intern (completing-read "Theme laden: "
                                  (mapcar #'symbol-name (custom-available-themes))
                                  nil t))))
  (mapc #'disable-theme (copy-sequence custom-enabled-themes))
  (load-theme theme t)
  (setq doom-theme theme)
  ;; Terminal-Frames wieder den iTerm2-Hintergrund uebernehmen lassen (s.u.):
  (when (fboundp '+tty/inherit-terminal-background)
    (+tty/inherit-terminal-background)))
(map! :leader :desc "Theme wechseln (sauber)" "h t" #'+theme/load)

;; --------------------------------------------------------------------------
;; Einheitlicher Hintergrund im Terminal (et): Theme-Hintergrund weglassen
;; --------------------------------------------------------------------------
;; Im GUI bleibt der Theme-Hintergrund (#010611). Im Terminal (et/emacsclient -t)
;; setzen wir den default-Hintergrund auf "unspecified-bg" -> Emacs uebermalt den
;; Terminal-Hintergrund NICHT, sondern laesst den iTerm2-Hintergrund durchscheinen.
;; Ergebnis: einheitliche Flaeche (auch fuer iTerm2-Transparenz/Blur), keine
;; Kante zwischen Emacs-Bereich und iTerm2-Chrome. Setzt du iTerm2s Hintergrund
;; auf #010611, sieht das Terminal exakt wie das GUI-Theme aus.
(defun +tty/inherit-terminal-background (&optional frame)
  "Laesst Terminal-Frames den iTerm2-Hintergrund uebernehmen (GUI bleibt Theme)."
  (let ((frame (or frame (selected-frame))))
    (unless (display-graphic-p frame)
      (set-face-background 'default "unspecified-bg" frame)
      ;; Zeilennummern-Spalte nicht mit eigenem BG uebermalen (sonst Streifen):
      (when (facep 'line-number)
        (set-face-background 'line-number "unspecified-bg" frame)))))
(add-hook 'after-make-frame-functions #'+tty/inherit-terminal-background)
(add-hook 'server-after-make-frame-hook #'+tty/inherit-terminal-background)
;; auch fuer den evtl. schon bestehenden (nicht-grafischen) Frame beim Laden:
(+tty/inherit-terminal-background)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
;; `relative' = Vim-Hybrid: aktuelle Zeile zeigt ihre echte Nummer, alle anderen
;; den Abstand nach oben/unten -> so kann man mit z.B. 5j / 10k gezielt springen.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; CUSTOM
(set-face-attribute 'default nil :height 160)

;; Globaler Zeilenabstand (in Pixeln)
;; (setq-default line-spacing 0.5)


;; Cursor
(after! evil
  (setq evil-normal-state-cursor '(box "#A0A0A0")   ;; Grau
        evil-insert-state-cursor '(box "#FFD700")   ;; Goldgelb
        evil-visual-state-cursor '(box "#FFD700"))) ;; Goldgelb
(setq-default cursor-type 'box)
(custom-set-faces
 '(cursor ((t (:background "#00D3D0" :foreground "#00D3D0")))))

;; Bilder inline anzeigen (Org Mode)
(setq org-startup-with-inline-images t)

;; Latex PDF Viewer
(after! tex
  ;; Standard: LatexMk benutzen
  (setq ;; PDF in Emacs via pdf-tools anzeigen
        TeX-view-program-selection '((output-pdf "PDF Tools"))
        ;; Quelle↔PDF SyncTeX-Server starten
        TeX-source-correlate-start-server t)

  ;; Quelle↔PDF Korrelation in LaTeX-Buffern aktivieren
  (add-hook 'LaTeX-mode-hook #'TeX-source-correlate-mode)
  ;; pdf-tools für geöffnete PDFs aktivieren
  (add-hook 'TeX-after-compilation-finished-functions #'TeX-revert-document-buffer))

;; GOLANG
;; vor dem Speichern formatieren -- NUR in Go-Dateien (sonst lief der Hook global)
(add-hook 'go-mode-hook
          (lambda () (add-hook 'before-save-hook #'gofmt-before-save nil t)))

;; hover fuer typen
(after! lsp-ui
  ;; Hover-Fenster aktivieren
  (setq lsp-ui-doc-enable t
        lsp-ui-doc-show-with-cursor nil
        lsp-ui-doc-show-with-mouse nil))
(after! lsp-mode
  (map! :map lsp-mode-map
        :n "Q" #'lsp-ui-doc-show))

;; --------------------------------------------------------------------------
;; Direkt zur Definition springen (Klasse/Interface/Enum) -- ohne Peek/Liste
;; --------------------------------------------------------------------------
;; Hintergrund: Durch das Modul-Flag `(lsp +peek)' belegt Doom den Definitions-
;; Handler mit `lsp-ui-peek-find-definitions' -- d.h. `gd' / `SPC c d' oeffnet ein
;; Peek-Fenster mit einer Liste statt direkt zu springen. Diese Befehle rufen den
;; LSP-Sprung direkt auf (ueber xref) und landen sofort in der Quelle.
(defun +java/jump-to-definition ()
  "Direkt zur Definition des Symbols unter dem Cursor springen (Klasse/Interface/
Enum/Methode) -- ohne Peek-/Referenzliste. Nutzt LSP, sonst xref als Fallback."
  (interactive)
  (if (bound-and-true-p lsp-mode)
      (lsp-find-definition)
    (call-interactively #'xref-find-definitions)))

(defun +java/jump-to-type-definition ()
  "Direkt zum TYP (Klasse/Interface/Enum) des Symbols unter dem Cursor springen.
Nuetzlich, wenn der Cursor auf einer Variablen steht und man in deren Typ will."
  (interactive)
  (if (bound-and-true-p lsp-mode)
      (lsp-find-type-definition)
    (user-error "Typ-Definition braucht einen aktiven LSP-Server")))

(map! :leader
      :desc "Definition: direkt springen" "c g" #'+java/jump-to-definition
      :desc "Typ-Definition: direkt springen" "c G" #'+java/jump-to-type-definition)


;; Open file in finder (macos)
(defun tu/open-in-finder ()
  "Öffne den Finder im Verzeichnis der aktuellen Datei."
  (interactive)
  (when buffer-file-name
    (shell-command (concat "open " (file-name-directory buffer-file-name)))))

;; Optional: Keybinding, z. B. unter SPC o f (Space-o-f)
(map! :leader
      :desc "Open in Finder"
      "o f" #'tu/open-in-finder)

;; binding for edit all occurrences
(map! :leader
      :desc "Edit all occurrences"
      "e a" #'iedit-mode)

;; Parent-Task wird DONE, wenn alle Childs DONE sind / Prozentberechnung / Saubere Logs
(after! org
  (setq org-log-done 'time
        org-log-into-drawer t
        org-enforce-todo-dependencies t
        org-hierarchical-todo-statistics t))


;; Latex Zeile-Zeile anstelle der Block Zeilen
(add-hook 'LaTeX-mode-hook #'visual-line-mode)
(setq evil-respect-visual-line-mode t)
(map! :map LaTeX-mode-map
      :n "j" #'evil-next-visual-line
      :n "k" #'evil-previous-visual-line)
(map! :map LaTeX-mode-map
      :n "0" #'evil-beginning-of-visual-line
      :n "$" #'evil-end-of-visual-line
      :n "^" #'evil-first-non-blank-of-visual-line)

;; kotlin in md aktivieren
(after! markdown-mode
  (setq markdown-fontify-code-blocks-natively t)

  ;; "kotlin" in ```kotlin auf kotlin-mode mappen
  (add-to-list 'markdown-code-lang-modes '("kotlin" . kotlin-mode))

  ;; optional, falls du auch ```kt benutzen willst
  (add-to-list 'markdown-code-lang-modes '("kt" . kotlin-mode)))

;; Such-/Auswahlfenster (vertico +childframe = vertico-posframe) NICHT springen lassen.
;; Ursache des "Herumspringens": das Posframe passt Groesse dynamisch an die Trefferzahl
;; an und wird dabei neu zentriert. -> feste Breite/Hoehe + kein Resizing = stabil.
(after! vertico
  ;; resize nil => vertico zeigt IMMER `vertico-count' Zeilen (auch mit Padding).
  ;; Dadurch ist die Hoehe konstant (kein Springen) und die Liste scrollt/rotiert
  ;; normal durch alle Treffer.
  (setq vertico-resize nil
        vertico-count 17))                    ; feste Anzahl sichtbarer Eintraege
(after! vertico-posframe
  ;; WICHTIG: `vertico-posframe-height' NICHT absolut setzen -- das nagelt die Hoehe
  ;; starr fest und verhindert das Mitscrollen der Kandidatenliste. Stattdessen Hoehe
  ;; automatisch (folgt `vertico-count', dank resize nil konstant) + min-height als
  ;; Untergrenze gegen Schrumpfen. Breite bleibt fix gegen horizontales Springen.
  (setq vertico-posframe-poshandler #'posframe-poshandler-frame-center  ; immer zentriert
        vertico-posframe-width 160            ; feste Breite (Zeichen)
        vertico-posframe-min-width 120        ; nicht schmaler werden
        vertico-posframe-height nil           ; Hoehe automatisch (= vertico-count, stabil)
        vertico-posframe-min-height (1+ vertico-count)))  ; Untergrenze: Prompt + Eintraege

;; Aufraeumen: eine fruehere Session hatte diese Befehle testweise auf das
;; vertico-buffer-Layout (Frame-Unterkante) gestellt. `add-to-list' ueberlebt aber
;; ein `doom/reload' (SPC h r r) -- die Eintraege bleiben sonst haengen und die Suche
;; klebt weiter unten. Darum hier explizit wieder entfernen -> zentrierte Posframe.
(after! vertico-multiform
  (dolist (cmd '(+java/goto-class +java/goto-class-anywhere
                 consult-fd consult-find consult-ripgrep consult-git-grep
                 consult-line consult-buffer consult-project-buffer
                 +default/search-project +default/search-project-for-symbol-at-point
                 +default/search-buffer +default/search-cwd +default/search-other-cwd
                 +search/project-latin1
                 find-file projectile-find-file))
    (setq vertico-multiform-commands
          (assq-delete-all cmd vertico-multiform-commands))))
;; Projectile: Eclipse-/JDT-".project"-Dateien NICHT als Projektwurzel werten.
;; Doom fuegt ".project" zu `projectile-project-root-files-bottom-up' hinzu. In einem
;; Multi-Modul-Maven-Projekt hat aber JEDES Modul eine Eclipse-".project" -- dadurch
;; wuerde "bottom-up" das tiefste Modul (z.B. entscheidungen-model) statt des Git-Roots
;; als Projekt erkennen. Folge: `SPC s p' sucht nur im Modul, nicht im Oberprojekt.
;; Loesung: ".project" als Marker entfernen -> die Git-Wurzel (Oberprojekt) gewinnt.
;; Eigene Projektwurzeln lassen sich weiterhin per ".projectile"-Datei markieren.
(after! projectile
  (setq projectile-project-root-files-bottom-up
        (remove ".project" projectile-project-root-files-bottom-up))
  ;; bereits gecachte (falsche) Wurzeln verwerfen, damit der Fix sofort greift:
  (when (and (boundp 'projectile-project-root-cache)
             (hash-table-p projectile-project-root-cache))
    (clrhash projectile-project-root-cache)))

;; --------------------------------------------------------------------------
;; Performance: "Doom wird beim Nutzen immer langsamer"
;; --------------------------------------------------------------------------
;; Die progressive Verlangsamung in einer Sitzung kommt typischerweise von
;; (1) dem Kompaktieren der Font-Caches (besonders mit Icon-Fonts wie hier durch
;;     corfu/vertico +icons -- DER haeufigste Grund fuer "immer langsamer") und
;; (2) zu haeufiger/aggressiver Garbage Collection.
(setq inhibit-compacting-font-caches t            ; Font-Cache nicht staendig kompaktieren (grosser Gewinn)
      fast-but-imprecise-scrolling t              ; fluessigeres Scrollen in grossen Dateien
      redisplay-skip-fontification-on-input t     ; beim Tippen nicht zwischendurch fontifizieren
      idle-update-delay 1.0                        ; UI-Elemente seltener aktualisieren
      jit-lock-defer-time 0)                       ; Fontification waehrend Eingabe aufschieben

;; GC fuer lange Sitzungen entspannen: gcmh sammelt im Leerlauf; eine hoehere Schwelle
;; reduziert die Anzahl der GC-Pausen waehrend der aktiven Arbeit.
(after! gcmh
  (setq gcmh-high-cons-threshold (* 256 1024 1024)))  ; 256 MB statt Default

;; ---- native-compilation (nur mit native-comp-Build, z.B. emacs-plus@30) ----
;; DER groesste Performance-Faktor: Elisp wird zu nativem Maschinencode kompiliert
;; (statt nur byte-compiled) -> Org/LSP/Redisplay 2-4x schneller. Diese Einstellungen
;; greifen nur, wenn Emacs mit native-comp gebaut ist; sonst sind sie einfach wirkungslos.
(when (and (fboundp 'native-comp-available-p) (native-comp-available-p))
  ;; Warnungen/Fehler der (einmaligen) Hintergrund-Kompilierung nicht als *Warnings*-
  ;; Buffer aufpoppen lassen -- sie sind fast immer harmlos und stoeren nur:
  (setq native-comp-async-report-warnings-errors 'silent
        native-comp-jit-compilation t              ; im Hintergrund JIT-kompilieren
        ;; mehr parallele Kompilier-Jobs = schneller durch den einmaligen Erstlauf:
        native-comp-async-jobs-number (max 1 (/ (num-processors) 2))))

;; --------------------------------------------------------------------------
;; Suche: Klassensuche (IntelliJ "Go to Class") + Latin-1-faehige Projektsuche
;; --------------------------------------------------------------------------

;; Klassen/Symbole projektweit suchen (IntelliJ Cmd+O "Go to Class"). Nutzt die
;; Workspace-Symbole von JDT.LS via consult-lsp -> tippen filtert live nach Klasse/Methode.
(defun +lsp/goto-class ()
  "Gruendliche projektweite Symbolsuche via JDT.LS (findet auch innere Klassen/Methoden).
Kann je nach Workspace-Groesse etwas dauern (LSP-Roundtrip)."
  (interactive)
  (require 'consult-lsp)
  (call-interactively #'consult-lsp-symbols))

;; Schnelle, Telescope-artige Klassensuche: statt LSP-Workspace-Symbole (Roundtrip,
;; teils langsam) werden die Klassen-DATEIEN asynchron per `fd' gelistet. In Java/Kotlin
;; ist der Dateiname = Klassenname -> das deckt "Go to Class" praktisch komplett ab.
;; `consult-fd' liefert dabei von Haus aus das Telescope-Gefuehl: async (sofort schnell),
;; `:category file' -> Datei-Icons (nerd-icons), Live-Vorschau und Match-Highlight.
(defun +java/goto-class (&optional arg)
  "Schnelle, Telescope-artige Klassensuche (IntelliJ \"Go to Class\").
Listet .java/.kt/.scala-Dateien im Projekt asynchron per `fd' (Dateiname = Klassenname)
-- mit Datei-Icons, Live-Vorschau und Match-Highlight, komplett OHNE LSP-Roundtrip.

Mit Praefix-Arg (\\[universal-argument]) stattdessen die gruendliche LSP-Symbolsuche
(`+lsp/goto-class' -- findet auch innere Klassen/Methoden)."
  (interactive "P")
  (if arg
      (+lsp/goto-class)
    (require 'consult)
    (let* ((root (or (doom-project-root) default-directory))
           ;; fd auf Klassen-Dateien vorfiltern; die dynamischen Suchargumente aus dem
           ;; Minibuffer haengt consult danach an -> Tippen filtert nur noch nach Namen.
           (consult-fd-args
            (append (if (listp consult-fd-args) consult-fd-args (list consult-fd-args))
                    '("--type f --extension java --extension kt --extension scala"))))
      (consult-fd root))))

;; Projektsuche fuer ISO-8859-1/Latin-1-Dateien (viele *.properties hier sind Latin-1
;; kodiert). ripgrep nimmt sonst UTF-8 an und findet Umlaute in Latin-1-Dateien NICHT.
;; Diese Variante liest die Dateien als Latin-1 -> Umlaute in *.properties werden gefunden.
;; (Die normale `SPC s p' bleibt UTF-8, passend fuer Java/XML-Quellen mit Umlauten.)
(defun +search/project-latin1 ()
  "Wie `SPC s p', liest die Dateien aber als ISO-8859-1 (fuer Latin-1-*.properties).
Nutzt Dooms `+vertico-file-search' und haengt `--encoding=iso-8859-1' an die
ripgrep-Argumente an (deshalb hier statt eines einfachen consult-ripgrep-Wrappers --
`+vertico-file-search' baut `consult-ripgrep-args' sonst intern komplett neu)."
  (interactive)
  (+vertico-file-search :args '("--encoding=iso-8859-1")))

;; --------------------------------------------------------------------------
;; "Go to Class" INKL. Dependencies/JARs (wie IntelliJ Cmd+O ueber Bibliotheken)
;; --------------------------------------------------------------------------
;; `SPC s c'/`SPC SPC' sehen bewusst nur Projektdateien. Fuer Klassen aus pom-
;; Dependencies (und dem JDK) nutzt dieser Befehl JDT.LS' eigene Typsuche
;; `java/searchSymbols' mit `:sourceOnly :json-false' -> auch Library-Typen.
;; Die Auswahl oeffnet den (dekompilierten bzw. angehaengten) Quelltext ueber die
;; jdt://-URI, sodass man den Inhalt anschauen kann.

(defun +java--class-anywhere-transformer (_workspace symbol-info)
  "Leichter consult-Transformer fuer die Dependency-Klassensuche.
Baut den Kandidaten NUR aus Name + Package (`containerName') -- bewusst OHNE
`lsp--uri-to-path': das wuerde jede jdt://-URI SOFORT dekompilieren
(`java/classFileContents' pro Treffer) und die Liste extrem verlangsamen.
Dekompiliert wird erst bei Auswahl/Vorschau (siehe `:state')."
  (let ((name      (lsp:symbol-information-name symbol-info))
        (container (lsp-get symbol-info :containerName)))
    (propertize
     (if (and container (not (string-empty-p container)))
         (format "%s  %s" name
                 (propertize container 'face 'completions-annotations))
       name)
     'consult--type (consult-lsp--symbols--kind-to-narrow symbol-info)
     'consult--candidate symbol-info
     'consult--container-name container)))

(defun +java--class-anywhere-annotate (cand)
  "Zeigt rechts nur die Symbol-Art (Class/Interface/Enum ...) -- das Package steht
schon im Kandidaten selbst (siehe `+java--class-anywhere-transformer')."
  (when-let ((si (get-text-property 0 'consult--candidate cand)))
    (concat "  " (or (alist-get (lsp:symbol-information-kind si) lsp-symbol-kinds) ""))))

(defun +java--class-anywhere-async-source (workspaces)
  "consult-Async-Source: Typen ueber JDT.LS `java/searchSymbols' inkl. Dependencies.
Wie `consult-lsp--symbols--make-async-source', aber Request = `java/searchSymbols'
mit `:sourceOnly :json-false' -> auch Klassen aus JARs/pom-Dependencies. Die Suche
retriggert bei jedem Tastendruck (JDT liefert nur begrenzt viele Treffer)."
  (lambda (sink)
    (let* ((cancel-token :+java-class-anywhere)
           (query-lsp
            (lambda (query)
              (with-lsp-workspaces workspaces
                (lsp-request-async
                 "java/searchSymbols"
                 ;; "*" -> Prefix/CamelCase-Suche (JDT-Suchmuster); sourceOnly=false
                 ;; bezieht Bibliotheks-Typen mit ein.
                 (list :query (concat query "*") :sourceOnly :json-false)
                 (lambda (res)
                   (funcall sink 'flush)
                   (funcall sink res)
                   (funcall sink [indicator finished]))
                 :mode 'detached
                 :no-merge t
                 :cancel-token cancel-token)))))
      (lambda (action)
        (pcase-exhaustive action
          ;; KEINE Leersuche beim Start: "*" wuerde saemtliche JAR-Klassen ziehen.
          ('setup (funcall sink action))
          ((pred stringp)
           (unless (string= "" action)
             (funcall sink [indicator running])
             (funcall query-lsp action))
           (funcall sink action))
          ('destroy
           (lsp-cancel-request-by-token cancel-token)
           (funcall sink action))
          (_ (funcall sink action)))))))

;;;###autoload
(defun +java/goto-class-anywhere ()
  "IntelliJ \"Go to Class\" INKL. Dependencies/JARs (Cmd+O ueber Bibliotheken).
Sucht Typen ueber JDT.LS `java/searchSymbols' -- also auch Klassen aus den
pom-Dependencies und dem JDK, nicht nur im Projekt. Die Auswahl oeffnet den
(dekompilierten bzw. ueber angehaengte Sources geladenen) Quelltext, sodass man
sich den Inhalt anschauen kann.

Ab 2 Zeichen wird live gesucht (JDT-Prefix/CamelCase). Fuer die schnelle,
rein projektlokale Dateisuche weiter `SPC s c' nutzen."
  (interactive)
  (require 'consult-lsp)
  (let* ((ws (or (lsp-workspaces)
                 (gethash (lsp-workspace-root default-directory)
                          (lsp-session-folder->servers (lsp-session)))))
         ;; Erst ab 2 Zeichen suchen -> vermeidet die "*"-Explosion ueber alle JARs.
         (consult-async-min-input 2))
    (unless ws
      (user-error "Kein aktiver LSP-Workspace -- erst eine Java-Datei oeffnen"))
    (consult--read
     (consult--async-pipeline
      (consult--async-min-input)
      (consult--async-throttle)
      (+java--class-anywhere-async-source ws)
      (consult--async-transform
       (apply-partially
        #'mapcan
        (lambda (ws-syms)
          ;; leichten Transformer verwenden (kein Dekompilieren pro Treffer):
          (let ((consult-lsp-symbols-transformer-function
                 #'+java--class-anywhere-transformer))
            (consult-lsp--symbols--make-transformer ws-syms)))))
      (consult--async-highlight))
     :prompt "Klasse (inkl. Dependencies) "
     :annotate #'+java--class-anywhere-annotate
     :require-match t
     :history t
     :add-history (thing-at-point 'symbol)
     :category 'consult-lsp-symbols
     :lookup #'consult--lookup-candidate
     :group (consult--type-group consult-lsp-symbols-narrow)
     :narrow (consult--type-narrow consult-lsp-symbols-narrow)
     ;; :state dekompiliert/oeffnet erst den AUSGEWAEHLTEN Treffer (jdt://) -- lazy.
     :state (consult-lsp--symbols--state))))

(map! :leader
      :desc "Go to Class (schnell, fd)"    "s c" #'+java/goto-class
      :desc "Symbolsuche (LSP, gruendlich)" "s C" #'+lsp/goto-class
      :desc "Klasse inkl. Dependencies"    "s a" #'+java/goto-class-anywhere
      :desc "Suche Projekt (Latin-1)"      "s P" #'+search/project-latin1)

;; Definition/Referenzen zusaetzlich auf SPC c j / SPC c J legen (analog zu
;; SPC c d / SPC c D). Die frueher hier liegende `consult-lsp-symbols'-Suche gibt
;; es weiter unter SPC s C (gruendlich) bzw. SPC s c (schnell).
(map! :leader
      :desc "Zur Definition (wie c d)"  "c j" #'+lookup/definition
      :desc "Referenzen (wie c D)"      "c J" #'+lookup/references)

;; Java/Spring-IDE-Erweiterungen (siehe docs/ und +java.el / +git.el):
;; Die fruehere handgepflegte `ent/run`-Konfiguration wird durch den
;; Run/Debug-Picker aus `.idea/runConfigurations` ersetzt (Single Source of Truth).
;; Bei Classpath-Problemen mit dem Jetty-Starter steht `+idea/run-mvn' (SPC m R)
;; als bewaehrter `mvn exec:java'-Fallback bereit.
(load! "+java")
(load! "+git")


;; refresh im docker mode
(after! docker
  (map! :map docker-container-mode-map
        :n "g r" #'tabulated-list-revert))

;; --------------------------------------------------------------------------
;; Treemacs (SPC o p): Sidebar automatisch so breit wie noetig
;; --------------------------------------------------------------------------
;; Problem: Bei fester `treemacs-width' werden lange Datei-/Ordnernamen
;; abgeschnitten (z.B. "annotat:", "behavio", "groupbo"). Loesung: nach dem
;; Oeffnen und nach jedem Auf-/Zuklappen die Breite an den laengsten sichtbaren
;; Eintrag anpassen -- begrenzt durch `+treemacs-max-width', mindestens
;; `treemacs-width' (damit es nie zu schmal wird).
(defvar +treemacs-max-width 70
  "Obergrenze (in Spalten) fuer die automatische Treemacs-Breite.")

(after! treemacs
  (defun +treemacs/fit-width-to-content (&rest _)
    "Treemacs-Fenster so breit machen wie der laengste sichtbare Eintrag.
Begrenzt auf `+treemacs-max-width', Untergrenze `treemacs-width'. Wirkt auf das
lokale Treemacs-Fenster -- unabhaengig davon, welches Fenster gerade fokussiert ist."
    (let ((win (treemacs-get-local-window)))
      (when (window-live-p win)
        (with-selected-window win
          (let ((longest 0))
            (save-excursion
              (goto-char (point-min))
              (while (not (eobp))
                (setq longest (max longest (- (line-end-position)
                                              (line-beginning-position))))
                (forward-line 1)))
            ;; +3 Puffer fuer Icon-/Rand-Breite; Icons zaehlen im Buffer nur als 1 Zeichen.
            (treemacs--set-width
             (max treemacs-width (min +treemacs-max-width (+ longest 3)))))))))

  ;; Initial beim Oeffnen (SPC o p) und nach jedem Expandieren/Kollabieren neu messen:
  (advice-add '+treemacs/toggle    :after #'+treemacs/fit-width-to-content)
  (advice-add 'treemacs-TAB-action  :after #'+treemacs/fit-width-to-content)
  (advice-add 'treemacs-RET-action  :after #'+treemacs/fit-width-to-content)
  (advice-add 'treemacs-toggle-node :after #'+treemacs/fit-width-to-content))
