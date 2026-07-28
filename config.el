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

;; SPC f d -> Verzeichnis im Projekt suchen und oeffnen (statt Dooms +default/dired).
;; projectile-find-dir listet alle Verzeichnisse des aktuellen Projekts (Completion).
(map! :leader :desc "Verzeichnis im Projekt suchen" "f d" #'projectile-find-dir)
;; Spiegel-Bindings unter dem Find-Prefix (gleiche Optik/Funktion):
;; SPC f c = Datei im Projekt finden WORTGENAU (projectile-find-file, zusammenhaengend).
;; Die FUZZY-Variante (Luecken erlaubt, wie IntelliJ) liegt auf SPC SPC (weiter unten).
;; SPC f C = Klasse inkl. Dependencies finden (identisch zu SPC s a)
(map! :leader
      :desc "Datei finden (wortgenau)" "f c" #'projectile-find-file
      :desc "Klasse inkl. Dependencies (wie SPC s a)" "f C" #'+java/goto-class-anywhere)

;; SPC f m -> "Find Method" wie IntelliJ (File Structure / Go to Symbol in File):
;; consult-imenu listet alle Methoden/Funktionen/Klassen der AKTUELLEN Datei als
;; schnellen Vertico-Picker (mit Icons, live-Filter) -- sieht aus wie Find File/Dir.
;; RET springt zur Definition. Fuer projektweite Symbol-/Klassensuche: SPC s c.
(map! :leader :desc "Methode im Projekt finden (LSP)" "f m" #'+find/project-method)
;; (Methoden NUR der aktuellen Datei weiterhin ueber SPC s i / consult-imenu.)

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
  (when (fboundp 'better-jumper-set-jump) (better-jumper-set-jump))
  (if (bound-and-true-p lsp-mode)
      (lsp-find-definition)
    (call-interactively #'xref-find-definitions)))

(defun +java/jump-to-type-definition ()
  "Direkt zum TYP (Klasse/Interface/Enum) des Symbols unter dem Cursor springen.
Nuetzlich, wenn der Cursor auf einer Variablen steht und man in deren Typ will."
  (interactive)
  (when (fboundp 'better-jumper-set-jump) (better-jumper-set-jump))
  (if (bound-and-true-p lsp-mode)
      (lsp-find-type-definition)
    (user-error "Typ-Definition braucht einen aktiven LSP-Server")))

;; --------------------------------------------------------------------------
;; Referenzen wie IntelliJ: genau EINE Referenz -> direkt dahin springen
;; --------------------------------------------------------------------------
;; Find Usages mit nur einem Treffer soll nicht erst eine 1-Zeilen-Liste zeigen,
;; sondern direkt springen (wie IntelliJ). Bei mehreren Treffern die normale Liste.
(defun +java/references-smart ()
  "Referenzen/Find Usages. Genau EINE Referenz (ohne die Deklaration) -> direkt
dahin springen (wie IntelliJ), sonst die uebliche Referenzliste. Ohne LSP: Fallback."
  (interactive)
  (if (not (bound-and-true-p lsp-mode))
      (call-interactively #'+lookup/references)
    (let* ((refs  (ignore-errors
                    (lsp-request "textDocument/references"
                                 (lsp--make-reference-params nil t)))) ; t = ohne Deklaration
           (items (and refs (lsp--locations-to-xref-items refs))))
      (cond
       ((null items)
        (message "Keine Referenzen gefunden (ausser der Deklaration)"))
       ((= (length items) 1)
        (when (fboundp 'better-jumper-set-jump) (better-jumper-set-jump))
        (xref-push-marker-stack)
        (let ((m (xref-location-marker (xref-item-location (car items)))))
          (pop-to-buffer-same-window (marker-buffer m))
          (goto-char m)
          (recenter))
        (message "Einzige Referenz -- direkt gesprungen (zurueck: C-o)"))
       (t (call-interactively #'+lookup/references))))))

(map! :leader
      :desc "Definition: direkt springen" "c g" #'+java/jump-to-definition
      :desc "Typ-Definition: direkt springen" "c G" #'+java/jump-to-type-definition)

;; WICHTIG (Performance): `g d' / `SPC c j' / `SPC c d' waren Dooms `+lookup/definition'.
;; Dessen Fallback-Kette grept bei fehlgeschlagenem/langsamem xref das GESAMTE Projekt
;; (hier: 8 Maven-Projekte im Workspace) durch -> "laedt ewig und springt dann nicht".
;; Diese drei jetzt ebenfalls direkt per LSP springen (wie `SPC c g'): sofortiger Sprung
;; in derselben Klasse, und bei Miss ein schnelles xref statt monorepo-weitem ripgrep.
;; `g d' nur in LSP-Buffern umbiegen (sonst bleibt Dooms Standard aktiv).
(after! lsp-mode (map! :map lsp-mode-map :n "g d" #'+java/jump-to-definition))
(map! :leader
      :desc "Definition: direkt springen (LSP)" "c d" #'+java/jump-to-definition
      :desc "JDT.LS: nur aktuelles Projekt"     "p P" #'+java/lsp-prune-to-current-project)

;; --------------------------------------------------------------------------
;; SPC j = "jump" -- Navigation (Definition/Referenzen/Super/Interface<->Impl)
;; --------------------------------------------------------------------------
;; j d = direkt zur Definition (LSP, kein Peek, kein projektweiter ripgrep-Fallback)
;; j r = Referenzen / Find Usages
;; j i = von der Implementierung zur Methode im Interface/Supertyp springen
;;       (lsp-java-open-super-implementation, IntelliJ "Go to Super Method")
;; j I = zwischen XService.java und XServiceImpl.java wechseln (+java/toggle-impl)
(map! :leader
      (:prefix ("j" . "jump")
       :desc "Zur Definition (direkt, LSP)"  "d" #'+java/jump-to-definition
       :desc "Referenzen (1 Treffer -> direkt)" "r" #'+java/references-smart
       :desc "Super-Methode (wie m i)"       "i" #'lsp-java-open-super-implementation
       :desc "Interface <-> Impl (wie m I)"  "I" #'+java/toggle-impl))

;; Projekt auf Fehler pruefen (IntelliJ "Build Project" / Ctrl+F9): kompiliert den
;; ganzen Reactor und listet ALLE Fehler projektweit (auch in nicht geoeffneten Dateien),
;; navigierbar mit ]e / [e. C-u = nur aktuelles Modul + Dependents (-amd).
(map! :leader
      :desc "Projekt pruefen (alle Fehler)" "c B" #'+java/check-project)

;; --- Fix fuer `SPC c x' (+default/diagnostics -> consult-lsp-diagnostics) ---
;; Der eingebaute Transformer formatiert jeden Eintrag mit "%-60.60s" -- also hart
;; auf 60 Zeichen abgeschnitten. Bei unseren tiefen Paketpfaden ist nach 60 Zeichen
;; erst ".../de/guidecom/entscheidun" erreicht: Klassenname UND Zeilennummer fallen
;; weg, alle Eintraege sehen gleich aus -> man landet gefuehlt in der "falschen Datei".
;; Eigener Transformer: "Dateiname:Zeile  Meldung  (Verzeichnis)" -- nichts wird
;; abgeschnitten, jede Zeile ist eindeutig ihrer Datei zuzuordnen (und filterbar).
(after! consult-lsp
  (defun +consult-lsp-diagnostics-transformer (file diag)
    "Wie der Original-Transformer, aber ohne 60-Zeichen-Truncation.
Zeigt `Dateiname:Zeile' gefolgt von der Meldung und dem (verkuerzten) Pfad."
    (let* ((wks   (lsp-workspace-root file))
           (rel   (if wks (f-relative file wks) file))
           (line  (lsp-translate-line
                   (1+ (lsp-get (lsp-get (lsp-get diag :range) :start) :line))))
           (base  (file-name-nondirectory file))
           (dir   (or (file-name-directory rel) ""))
           (msg   (replace-regexp-in-string
                   "[ \t\n\r]+" " " (or (lsp-get diag :message) ""))))
      (propertize
       (format "%-34s %s  %s"
               (concat (propertize base 'face 'consult-file)
                       ":" (number-to-string line))
               (string-trim msg)
               (propertize dir 'face 'completions-annotations))
       'consult--candidate (cons file diag)
       'consult--type (consult-lsp--diagnostics--severity-to-type diag))))
  (setq consult-lsp-diagnostics-transformer-function
        #'+consult-lsp-diagnostics-transformer))


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

;; Vertico laeuft wieder im normalen Minibuffer UNTEN (Doom-Original) -- KEIN
;; Childframe/Posframe mehr (das `+childframe'-Flag ist in init.el entfernt).
(after! vertico
  ;; grow-only: der Minibuffer waechst mit der Trefferzahl bis `vertico-count' und
  ;; schrumpft nicht bei jedem Tastendruck -> ruhiges, stocknahes Verhalten unten.
  (setq vertico-resize 'grow-only
        vertico-count 17))                    ; max. Anzahl sichtbarer Eintraege

;; Aufraeumen: eine fruehere Session hatte diese Befehle testweise auf das
;; vertico-buffer-Layout (Frame-Unterkante) gestellt. `add-to-list' ueberlebt aber
;; ein `doom/reload' (SPC h r r) -- die Eintraege bleiben sonst haengen. Darum hier
;; explizit entfernen -> es bleibt beim normalen Minibuffer unten.
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
  "Literale Projektsuche in ISO-8859-1/Latin-1-Dateien (fuer Latin-1-*.properties).
Wie `SPC s p', aber (a) liest die Dateien als ISO-8859-1 -> findet Umlaute in
Latin-1-*.properties, und (b) sucht KOMPLETT LITERAL (`-F'/fixed-strings): die
Eingabe wird 1:1 gesucht -- Leerzeichen und Regex-Zeichen wie `.' `(' `*' zaehlen
woertlich, nichts wird als Regex interpretiert. Ideal fuer Property-Keys wie
`ent.db.server'. Zusatz-Flags weiter per ` -- ...' moeglich (z.B. `-s' case-sensitiv)."
  (interactive)
  (+vertico-file-search :args '("--encoding=iso-8859-1" "-F")))

;;;###autoload
(defun +search/project-literal ()
  "KOMPLETT LITERALE Projektsuche (UTF-8), wie `SPC s p' aber mit `-F'/fixed-strings.
Die Eingabe wird exakt so gesucht, wie sie dasteht -- Leerzeichen und Regex-Zeichen
(`.' `(' `[' `*' `?' ...) werden woertlich genommen, nichts als Regex interpretiert.
Fuer Latin-1-*.properties stattdessen `SPC s P' (liest zusaetzlich als ISO-8859-1)."
  (interactive)
  (+vertico-file-search :args '("-F")))

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
      :desc "Suche literal+Latin-1 (-F)"   "s P" #'+search/project-latin1
      :desc "Suche literal (fixed, -F)"    "s F" #'+search/project-literal)

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

;; --------------------------------------------------------------------------
;; Syntax-Highlighting fuer .properties (conf-javaprop-mode)
;; --------------------------------------------------------------------------
;; conf-javaprop-mode faerbt von Haus aus nur Kommentare und (theme-abhaengig oft
;; unsichtbar, im tj-Theme z.B. = Standardtextfarbe) den Key. Separator `=`/`:`
;; und Wert bleiben voellig ungefaerbt -> es sieht "ohne Highlighting" aus.
;; Darum hier zusaetzliche Font-Lock-Regeln, theme-unabhaengig gut sichtbar:
;;   Key     -> keyword-face   (im tj-Theme lila)
;;   `=`/`:` -> operator-face  (Separator)
;;   Wert    -> string-face    (gruen)
;;   ${..}/@..@ -> constant-face (Platzhalter, z.B. ${java.io.tmpdir}, Maven-Filter)
(defun +conf/properties-highlight ()
  "Zusaetzliches Highlighting fuer key=value, Separator und ${..}/@..@-Platzhalter."
  (font-lock-add-keywords
   nil
   '(;; key <sep> value -- Kommentarzeilen (# / !) sind ueber das erste Zeichen ausgeschlossen:
     ("^[ \t]*\\([^#!:=[:space:]][^:=\n]*\\)\\([:=]\\)\\(.*\\)$"
      (1 'font-lock-keyword-face t)
      (2 'font-lock-operator-face t)
      (3 'font-lock-string-face t))
     ;; ${...}-Platzhalter ueber dem Wert hervorheben (z.B. ${tenant.info.tenant}):
     ("\\${[^}\n]*}" 0 'font-lock-constant-face prepend)
     ;; @...@-Platzhalter (Maven-Resource-Filtering):
     ("@[A-Za-z0-9_.:-]+@" 0 'font-lock-constant-face prepend))
   'append)
  (when (bound-and-true-p font-lock-mode)
    (font-lock-flush)))

;; conf-javaprop-mode ist von conf-mode abgeleitet -> Hook nur an conf-mode haengen;
;; dann greift es fuer .properties UND generische conf-Dateien (ohne Doppel-Fontify).
(add-hook 'conf-mode-hook #'+conf/properties-highlight)

;; Dooom Docker Integration
;; Spaltenbreiten anpassen
(after! docker
  (setf (plist-get
         (seq-find
          (lambda (column)
            (equal (plist-get column :name) "Ports"))
          docker-container-columns)
         :width)
        35))

;; --------------------------------------------------------------------------
;; SPC SPC: FUZZY/FLEX-Dateisuche (Luecken erlaubt, wie IntelliJ)
;; --------------------------------------------------------------------------
;; Dooms Standard-orderless matcht ein eingegebenes Wort als ZUSAMMENHAENGENDEN
;; Teilstring (orderless-literal) -> "AgendapunktService" findet NICHT
;; "AgendapunktDummyService". Fuer SPC SPC stellen wir das Matching auf FLEX um
;; (Zeichen in Reihenfolge, mit Luecken) -- genau wie IntelliJs Datei-/Symbolsuche.
;; SPC f c bleibt BEWUSST wortgenau (unveraendert projectile-find-file), fuer exakte
;; zusammenhaengende Treffer.
(defun +find/find-file-fuzzy ()
  "Projektdatei-Suche mit FUZZY/FLEX-Matching (Luecken erlaubt, wie IntelliJ).
`AgendapunktService' findet damit auch `AgendapunktDummyService' (Zeichen in
Reihenfolge, mit Luecken). Fuer die wortgenaue Variante gibt es weiterhin `SPC f c'."
  (interactive)
  (require 'orderless)
  (let ((orderless-matching-styles '(orderless-flex)))
    (call-interactively #'projectile-find-file)))

(map! :leader
      :desc "Datei finden (fuzzy, wie IntelliJ)" "SPC" #'+find/find-file-fuzzy)

;; SPC f M = Methodensuche wie SPC f m, aber INKL. Dependency-Quellprojekte
;; (alle JDT.LS-Workspace-Ordner, z.B. service-framework-core). Gleiche flache
;; Vertico-Optik; Projektname steht im Pfad. Fuer Library-TYPEN: SPC s a.
(map! :leader
      :desc "Methode inkl. Dependencies finden" "f M" #'+find/project-method-deps)

;; SPC c m = Methoden/Struktur der AKTUELLEN Datei auflisten und hinspringen
;; (consult-imenu, gleiche Liste wie SPC s i). Fuer methodenweite Suche im ganzen
;; Projekt: SPC f m, inkl. Dependencies: SPC f M.
(map! :leader
      :desc "Methoden dieser Datei (imenu)" "c m" #'consult-imenu)

;; --------------------------------------------------------------------------
;; gD = zur IMPLEMENTIERUNG springen (wie IntelliJ Ctrl+Alt+B)
;; --------------------------------------------------------------------------
;; gd springt zur Definition (bei Interfaces also ins Interface). gD springt
;; stattdessen in die IMPLEMENTIERUNG. Genau EINE Implementierung -> direkt dahin
;; (wie IntelliJ), sonst die uebliche Auswahlliste. Ohne LSP: Fallback. Zurueck: C-o.
(defun +java/implementation-smart ()
  "Zur Implementierung springen (wie IntelliJ Ctrl+Alt+B). Genau EINE Implementierung
-> direkt dahin springen, sonst Liste. Ohne LSP: Fallback auf +lookup/implementations."
  (interactive)
  (if (not (bound-and-true-p lsp-mode))
      (call-interactively #'+lookup/implementations)
    (let* ((locs  (ignore-errors
                    (lsp-request "textDocument/implementation"
                                 (lsp--text-document-position-params))))
           (items (and locs (lsp--locations-to-xref-items locs))))
      (cond
       ((null items)
        (message "Keine Implementierung gefunden"))
       ((= (length items) 1)
        (when (fboundp 'better-jumper-set-jump) (better-jumper-set-jump))
        (xref-push-marker-stack)
        (let ((m (xref-location-marker (xref-item-location (car items)))))
          (pop-to-buffer-same-window (marker-buffer m))
          (goto-char m)
          (recenter))
        (message "Einzige Implementierung -- direkt gesprungen (zurueck: C-o)"))
       (t (call-interactively #'+lookup/implementations))))))

(after! lsp-mode
  (map! :map lsp-mode-map :n "g D" #'+java/implementation-smart))

;; --------------------------------------------------------------------------
;; Find-File: kompilierte bin/-Pfade (Eclipse-Output) ignorieren
;; --------------------------------------------------------------------------
;; In den Modulen liegen untracked `bin/'-Ordner (Eclipse-Build-Output, z.B.
;; entscheidungen-webapp/bin/src/...). Sie sind NICHT in .gitignore, daher tauchen
;; sie in SPC SPC / find-file auf. Projectile listet Dateien hier ueber `fd'
;; (projectile-git-use-fd = t) -> wir schliessen `bin' per `-E bin' aus. Zusaetzlich
;; fuer den git-ls-files-Fallback (ohne fd) `-x bin'. Der PERSISTENTE Projekt-Cache
;; muss danach einmal neu: SPC p i (projectile-invalidate-cache).
(after! projectile
  (unless (string-match-p "-E bin\\b" projectile-git-fd-args)
    (setq projectile-git-fd-args (concat projectile-git-fd-args " -E bin")))
  (setq projectile-git-command "git ls-files -zco --exclude-standard -x bin"))

;; --------------------------------------------------------------------------
;; find-file: Treffer in Split-Fenster oeffnen (statt im selben Buffer)
;; --------------------------------------------------------------------------
;; Ueber Embark: der project-file-Kandidat wird per Transformer in den absoluten
;; Pfad aufgeloest, die Aktion bekommt also den fertigen Pfad. `V' = vertikaler
;; Split (Fenster rechts, nebeneinander, wie Vim :vsplit), `|' = horizontaler
;; Split (Fenster unten). Bereits vorhanden: `o' = find-file-other-window.
(after! embark
  (defun +embark/find-file-vsplit (file)
    "Datei in vertikalem Split (Fenster RECHTS, nebeneinander) oeffnen."
    (interactive "FDatei: ")
    (select-window (split-window-right))
    (find-file file))
  (defun +embark/find-file-hsplit (file)
    "Datei in horizontalem Split (Fenster UNTEN) oeffnen."
    (interactive "FDatei: ")
    (select-window (split-window-below))
    (find-file file))
  (defun +embark/switch-buffer-vsplit (buffer)
    "Buffer in vertikalem Split (Fenster RECHTS) oeffnen."
    (interactive "BBuffer: ")
    (select-window (split-window-right))
    (switch-to-buffer buffer))
  (define-key embark-file-map   "V" #'+embark/find-file-vsplit)
  (define-key embark-file-map   "|" #'+embark/find-file-hsplit)
  (define-key embark-buffer-map "V" #'+embark/switch-buffer-vsplit))

;; Direkte Ein-Tasten-Kuerzel im Vertico-Minibuffer (ohne vorher C-; zu druecken):
;; C-c v = vertikaler Split (rechts), C-c s = horizontaler Split (unten).
;; Technik: den Embark-Aktions-Tastendruck vorab in die Eingabe schieben und
;; embark-act ausloesen -> agiert auf dem aktuell markierten Treffer.
(after! vertico
  (defun +vertico/open-vsplit ()
    "Markierten Treffer in vertikalem Split (Fenster rechts) oeffnen."
    (interactive)
    (require 'embark)
    (setq unread-command-events (listify-key-sequence "V"))
    (embark-act))
  (defun +vertico/open-hsplit ()
    "Markierten Treffer in horizontalem Split (Fenster unten) oeffnen."
    (interactive)
    (require 'embark)
    (setq unread-command-events (listify-key-sequence "|"))
    (embark-act))
  (define-key vertico-map (kbd "C-c v") #'+vertico/open-vsplit)
  (define-key vertico-map (kbd "C-c s") #'+vertico/open-hsplit)
  ;; Shift+Enter (GUI): Treffer direkt im vertikalen Split (rechts) oeffnen
  (define-key vertico-map (kbd "S-<return>") #'+vertico/open-vsplit))
