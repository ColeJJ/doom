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

;; --------------------------------------------------------------------------
;; Datei-/Klassen-Historie mit Live-Diff-Vorschau (Telescope "git_bufcommits")
;; --------------------------------------------------------------------------
;; Zeigt alle Commits, die die AKTUELLE Datei geaendert haben, als consult-Picker
;; -- neueste zuerst. Waehrend man durch die Liste blaettert, zeigt die Vorschau
;; live den Diff GENAU DIESER Datei im jeweiligen Commit (git show <hash> -- FILE).
;; So kann man die historischen Aenderungen Commit fuer Commit visuell durchgehen.
;; (Ergaenzung zum eingebauten `magit-log-buffer-file'.)

(defun +git--file-history-candidates (rel)
  "consult-Kandidaten (Commits, die REL beruehrt haben) -- Hash als Text-Property.
Format je Zeile aus git: HASH \\x1f DATUM \\x1f AUTOR \\x1f BETREFF."
  (mapcar
   (lambda (l)
     (pcase-let ((`(,hash ,date ,author ,subject) (split-string l "\x1f")))
       (propertize
        (format "%-9s %s  %-18s %s"
                (propertize (or hash "") 'face 'magit-hash)
                (propertize (or date "") 'face 'magit-log-date)
                (truncate-string-to-width (or author "") 18 nil ?\s)
                (or subject ""))
        'commit hash)))
   (split-string
    (shell-command-to-string
     ;; --follow: folgt Umbenennungen bei der AUFLISTUNG der Commits.
     (format "git log --follow --date=short --pretty=format:%%h%%x1f%%ad%%x1f%%an%%x1f%%s -- %s"
             (shell-quote-argument rel)))
    "\n" t)))

(defun +git--file-history-render (buf root rel hash)
  "Diff von REL im Commit HASH nach BUF rendern (in ROT/GRUEN, diff-mode).
Wichtig: `default-directory' wird INNERHALB von BUF auf ROT gesetzt -- sonst liefe
`git show' im (evtl. aus einem frueheren Aufruf stammenden) alten Verzeichnis des
History-Buffers und wuerfe \"fatal: bad revision\"."
  (when hash
    (with-current-buffer buf
      (setq-local default-directory root)
      (let ((inhibit-read-only t)
            (default-directory root))
        (erase-buffer)
        (insert (shell-command-to-string
                 (format "git show --stat --patch %s -- %s"
                         hash (shell-quote-argument rel))))
        (when (= (point-max) (point-min))
          (insert (format "(keine Aenderung an %s in %s -- evtl. Umbenennung vor diesem Commit)"
                          rel hash)))
        (goto-char (point-min))
        (diff-mode)
        (setq-local default-directory root)))
    (display-buffer buf)))

;;;###autoload
(defun +git/file-history ()
  "Commit-History der AKTUELLEN Datei mit Live-Diff-Vorschau (wie Telescope git_bufcommits).
Blaettern zeigt live den Diff dieser Datei im jeweiligen Commit; RET laesst die
Vorschau als Diff-Buffer offen, damit man die Aenderung in Ruhe anschauen kann.
Fuer die native Magit-Ansicht siehe `magit-log-buffer-file' (SPC g L)."
  (interactive)
  (require 'consult)
  (unless (buffer-file-name) (user-error "Kein Datei-Buffer"))
  (let* ((root (or (magit-toplevel) (user-error "Kein Git-Repository")))
         (file (buffer-file-name))
         (default-directory root)
         (rel  (file-relative-name file root))
         (cands (+git--file-history-candidates rel))
         (buf  (get-buffer-create "*Git File History*")))
    (unless cands (user-error "Keine Commit-History fuer %s" rel))
    (consult--read
     cands
     :prompt (format "Commits von %s: " (file-name-nondirectory rel))
     :category 'git-file-commit
     :require-match t
     :sort nil
     ;; KEIN eigenes :lookup -- consult liefert dem State direkt den ausgewaehlten
     ;; Kandidaten-Text; der Hash ist dessen erstes Token (siehe Format oben). Ein
     ;; Text-Property (`commit') ueberlebt den Lookup NICHT -> daher aus dem Text lesen.
     :state
     (lambda (action cand)
       (pcase action
         ((or 'preview 'return)
          (when-let* ((cand)
                      (hash (car (split-string (substring-no-properties cand))))
                      ((string-match-p "\\`[0-9a-f]+\\'" hash)))
            (+git--file-history-render buf root rel hash))))))))

;; Worktree-Schnellzugriff (entspricht 'Z' im Magit-Status):
;;   Z b  neue Worktree + Branch | Z g  zu Worktree wechseln | Z c  Worktree auschecken
(map! :leader :desc "Git Worktree" "g w" #'magit-worktree)

;; Datei-Historie: SPC g h = Telescope-artiger Commit-Picker mit Diff-Vorschau,
;; SPC g H = git-timemachine (Datei-Versionen mit n/p schrittweise durchblaettern),
;; SPC g L = native Magit-Datei-Historie (magit-log-buffer-file).
;; SPC g d = Diff der AKTUELLEN Datei gegen HEAD (letzter Commit) in einem
;; Magit-Diff-Buffer (Side-Buffer, farbig, navigierbar -- wie die Commit-Ansicht).
;; Navigation im Diff: n/p (Hunk), TAB (auf-/zuklappen), C-c C-t (Wort-Diff),
;; RET springt an die Stelle in der Datei, q schliesst. Fuer die inline-Variante
;; direkt im Datei-Buffer gibt es die Fringe-Marker (diff-hl) + SPC g v (Popup).
(map! :leader
      :desc "Datei-Diff vs HEAD" "g d" #'magit-diff-buffer-file)

(map! :leader
      :desc "Datei-Historie (Diff-Vorschau)" "g h" #'+git/file-history
      :desc "Datei-Timemachine (n/p)"        "g H" #'git-timemachine
      :desc "Datei-Historie (Magit-Log)"     "g L" #'magit-log-buffer-file)

;; git-timemachine: evil Normal-State faengt sonst n/p ab (Suche/Paste). evil-collection
;; legt zwar eine Normal-State-Map an, bindet dort aber weder n noch p -> hier explizit:
;; n = naechste (neuere) Revision, p = vorherige (aeltere), q = Ende.
(map! :after git-timemachine
      :map git-timemachine-mode-map
      :n "n" #'git-timemachine-show-next-revision
      :n "p" #'git-timemachine-show-previous-revision
      :n "N" #'git-timemachine-show-previous-revision
      :n "b" #'git-timemachine-blame
      :n "w" #'git-timemachine-kill-abbreviated-revision
      :n "q" #'git-timemachine-quit)

;; --------------------------------------------------------------------------
;; Git-Gutter (diff-hl) -- IntelliJ-artige Interaktion am Fringe-Marker
;; --------------------------------------------------------------------------
;; Die farbigen Balken links (hinzugefuegt/geaendert/geloescht) liefert Dooms
;; `vc-gutter +pretty' via `diff-hl' bereits live (diff-hl-flydiff-mode, aktualisiert
;; beim Tippen). Hier nur die IntelliJ-Extras: Klick auf den Marker oeffnet ein Popup
;; mit der Aenderung (inkl. Buttons: verwerfen/stagen/kopieren/naechster). Per Tastatur
;; das Popup ueber SPC g v.
(after! diff-hl
  ;; Klick auf den Fringe-Marker -> Popup mit dem Diff-Hunk (wie IntelliJ-Gutter-Klick):
  (when (fboundp 'diff-hl-show-hunk-mouse-mode)
    (global-diff-hl-show-hunk-mouse-mode 1)))

;; SPC g v = Hunk unter dem Cursor als Popup anzeigen (Vorschau der Aenderung).
;; Ergaenzt die schon vorhandenen: SPC g r (Hunk verwerfen), SPC g S (Hunk/Datei
;; stagen), ]d / [d bzw. SPC g ] / SPC g [ (naechster/vorheriger Hunk).
(map! :leader
      :desc "Hunk anzeigen (Popup)" "g v" #'diff-hl-show-hunk)


;; --------------------------------------------------------------------------
;; eDiff: schnell in den EIGENEN Buffer springen und dort editieren
;; --------------------------------------------------------------------------
;; Man KANN die eDiff-Variant-Buffer jederzeit direkt editieren (einfach mit der
;; Maus/Fenster reinklicken und tippen) -- eDiff erkennt die Aenderung, mit `!'
;; im Steuerfenster werden die Diffs danach neu berechnet. `E' springt zusaetzlich
;; vom Steuerfenster direkt an die AKTUELLE Diff-Stelle im "eigenen" Buffer
;; (C = Working-Tree bei 3-Wege, sonst B = rechts) und setzt den Cursor dorthin.
(defun +ediff/edit-mine ()
  "An die aktuelle Diff-Stelle im eigenen Buffer springen (C bei 3-Wege, sonst B).
Danach normal editieren; mit `!' (im eDiff-Steuerfenster) die Diffs neu berechnen."
  (interactive)
  (let ((ctl (cond ((and (bound-and-true-p ediff-control-buffer)
                         (buffer-live-p ediff-control-buffer))
                    ediff-control-buffer)
                   ((derived-mode-p 'ediff-mode) (current-buffer))
                   (t (seq-find (lambda (b) (with-current-buffer b
                                              (derived-mode-p 'ediff-mode)))
                                (buffer-list))))))
    (unless ctl (user-error "Keine aktive eDiff-Sitzung gefunden"))
    (with-current-buffer ctl
      (let* ((type (if (and (bound-and-true-p ediff-3way-job)
                            (bound-and-true-p ediff-buffer-C)
                            (buffer-live-p ediff-buffer-C))
                       'C 'B))
             (buf (ediff-get-buffer type))
             (n   ediff-current-difference)
             (ov  (and (integerp n) (>= n 0)
                       (ignore-errors (ediff-get-diff-overlay n type)))))
        (unless (buffer-live-p buf)
          (user-error "Ziel-Buffer nicht verfuegbar"))
        (select-window (or (get-buffer-window buf) (display-buffer buf)))
        (when (overlayp ov)
          (goto-char (overlay-start ov))
          (recenter))
        (message "Editiermodus im %s-Buffer -- zurueck mit C-x o, danach `!' zum Neuberechnen"
                 (symbol-name type))))))

;; `E' im eDiff-Steuerfenster an die neue Funktion binden (eDiff baut seine Map erst
;; beim Start auf -> ueber den Setup-Hook):
(with-eval-after-load 'ediff
  (add-hook 'ediff-keymap-setup-hook
            (lambda () (define-key ediff-mode-map (kbd "E") #'+ediff/edit-mine))))

;; Zurueck ins eDiff-Steuerfenster (wo n/p/a/b/!/q wirken), nachdem man in einen
;; Variant-Buffer geklickt/gesprungen ist. `C-x o' tut das ebenfalls (Setup ist
;; `plain', also ein Frame) -- `C-c e' ist der direkte, gezielte Weg und wirkt
;; auch im Insert-State (Chord statt Leader).
(defun +ediff/goto-control ()
  "Ins eDiff-Steuerfenster (`*Ediff Control Panel*') wechseln -- dort n/p/a/b/!/q."
  (interactive)
  (let ((ctl (cond ((and (bound-and-true-p ediff-control-buffer)
                         (buffer-live-p ediff-control-buffer))
                    ediff-control-buffer)
                   ((derived-mode-p 'ediff-mode) (current-buffer))
                   (t (seq-find (lambda (b) (with-current-buffer b
                                              (derived-mode-p 'ediff-mode)))
                                (buffer-list))))))
    (unless ctl (user-error "Keine aktive eDiff-Sitzung"))
    (let ((win (get-buffer-window ctl t)))   ; t = ueber alle Frames suchen
      (if win
          (progn (select-frame-set-input-focus (window-frame win))
                 (select-window win))
        (switch-to-buffer ctl)))
    (ignore-errors (ediff-recenter))))

(global-set-key (kbd "C-c e") #'+ediff/goto-control)

(provide '+git)
;;; +git.el ends here

;; --------------------------------------------------------------------------
;; Git Blame wie IntelliJ (Annotate): Alters-Heatmap LINKS am Code  --  SPC g B
;; --------------------------------------------------------------------------
;; Dooms Default SPC g B = `magit-blame' -> breite Ueberschriften-Bloecke UEBER dem
;; Code ("langgezogen"). Stattdessen `vc-annotate' (eingebaut, git-Backend): schmale
;; Spalte am linken Rand (Datum/Autor) und jede Zeile nach ALTER eingefaerbt --
;; frisch = rot/orange ... alt = blau/violett, genau wie IntelliJs Annotate-Heatmap.
;; In der Ansicht:  RET/Enter = Diff des Commits dieser Zeile (die Aenderung sehen),
;;                  D = kompletter Changeset-Diff,  l = Log,  q = schliessen.
(map! :leader
      :desc "Inline-Blame (im Buffer, Toggle)" "g B" #'+git-blame-inline-mode
      :desc "Annotate separat (vc-annotate)"    "g A" #'vc-annotate)

(after! vc-annotate
  ;; Farbe als VORDERGRUND (nicht als grelle Flaeche) -- auf dunklem Theme lesbar.
  (setq vc-annotate-background-mode nil
        ;; Alters-Heatmap (Alter in Tagen -> Farbe): frisch warm, alt kuehl.
        vc-annotate-color-map
        '((  2 . "#ff5555")    ; wenige Tage: knallrot (ganz frisch)
          (  7 . "#ff8c42")    ; ~1 Woche: orange
          ( 14 . "#ffd166")    ; ~2 Wochen: gelb
          ( 30 . "#c3e88d")    ; ~1 Monat: hellgruen
          ( 60 . "#89ddff")    ; ~2 Monate: hellblau
          ( 90 . "#82aaff")    ; ~1 Quartal: blau
          (180 . "#7e7fff")    ; ~halbes Jahr: blauviolett
          (360 . "#b085f5"))   ; ~1 Jahr: violett (alt)
        vc-annotate-very-old-color "#6c6f93")) ; aelter als 1 Jahr: gedaempft

;; In der Annotate-Ansicht: Enter -> Diff/Aenderung des Commits der aktuellen Zeile
;; (Doom/evil faengt RET sonst ab -> explizit im Normal-State binden).
(map! :after vc-annotate
      :map vc-annotate-mode-map
      :n "RET" #'vc-annotate-show-diff-revision-at-line
      :n "d"   #'vc-annotate-show-diff-revision-at-line
      :n "D"   #'vc-annotate-show-changeset-diff-revision-at-line
      :n "l"   #'vc-annotate-show-log-revision-at-line
      :n "a"   #'vc-annotate-revision-previous-to-line
      :n "q"   #'quit-window)

;; --------------------------------------------------------------------------
;; Inline Git Blame / Annotate im SELBEN Buffer  --  SPC g B (Toggle)
;; --------------------------------------------------------------------------
;; Wie IntelliJs Annotate direkt am Code (kein separater Buffer): `git blame' wird
;; gelesen und Commit-Kuerzel + Datum je Zeile in der LINKEN Margin eingeblendet,
;; nach ALTER eingefaerbt (frisch=rot ... alt=blau/violett). Das Syntax-Highlighting
;; des Codes bleibt vollstaendig erhalten (nur die Margin traegt die Farbe). Waehrend
;; der Mode aktiv ist, ist der Buffer schreibgeschuetzt und RET zeigt den Commit-Diff
;; der aktuellen Zeile; `q' oder erneut `SPC g B' schaltet aus.

(defvar +git-blame-age-colors
  '((  2 . "#ff5555")   ; wenige Tage: knallrot (ganz frisch)
    (  7 . "#ff8c42")   ; ~1 Woche: orange
    ( 14 . "#ffd166")   ; ~2 Wochen: gelb
    ( 30 . "#c3e88d")   ; ~1 Monat: hellgruen
    ( 60 . "#89ddff")   ; ~2 Monate: hellblau
    ( 90 . "#82aaff")   ; ~1 Quartal: blau
    (180 . "#7e7fff")   ; ~halbes Jahr: blauviolett
    (360 . "#b085f5"))  ; ~1 Jahr: violett
  "Alters-Heatmap (Alter in Tagen -> Farbe) fuer die Inline-Blame-Margin.")

(defvar +git-blame-very-old-color "#6c6f93"
  "Farbe fuer Zeilen aelter als der groesste Eintrag in `+git-blame-age-colors'.")

(defvar-local +git-blame--overlays nil "Aktive Blame-Overlays dieses Buffers.")
(defvar-local +git-blame--line-data nil "Hash: Zeilennummer -> (:hash :author :epoch).")
(defvar-local +git-blame--old-margin nil "Vorheriger left-margin-width zum Wiederherstellen.")
(defvar-local +git-blame--old-ro nil "War der Buffer vorher schreibgeschuetzt?")

(defun +git-blame--age-color (days)
  "Heatmap-Farbe fuer ein Alter von DAYS Tagen."
  (or (cdr (seq-find (lambda (c) (<= days (car c))) +git-blame-age-colors))
      +git-blame-very-old-color))

(defun +git-blame--data (file)
  "`git blame --line-porcelain' fuer FILE parsen -> Hash Zeilennr -> Plist."
  (let ((wbuf (generate-new-buffer " *git-blame-out*"))
        (data (make-hash-table :test 'eql))
        (default-directory (file-name-directory file)))
    (unwind-protect
        (when (zerop (process-file "git" nil wbuf nil "blame"
                                   "--line-porcelain" "--"
                                   (file-name-nondirectory file)))
          (with-current-buffer wbuf
            (goto-char (point-min))
            (let (hash author epoch final)
              (while (not (eobp))
                (cond
                 ((looking-at "^\\([0-9a-f]\\{40\\}\\) [0-9]+ \\([0-9]+\\)")
                  (setq hash  (match-string 1)
                        final (string-to-number (match-string 2))))
                 ((looking-at "^author \\(.+\\)")        (setq author (match-string 1)))
                 ((looking-at "^author-time \\([0-9]+\\)") (setq epoch (string-to-number (match-string 1))))
                 ((looking-at "^\t")
                  (when final
                    (puthash final (list :hash (substring hash 0 7)
                                         :author author :epoch epoch)
                             data)
                    (setq final nil author nil epoch nil))))
                (forward-line 1))))
          data)
      (kill-buffer wbuf))))

(defun +git-blame-inline--apply ()
  "Overlays mit Margin-Annotation fuer jede Zeile setzen (nach Alter eingefaerbt)."
  (let* ((data (+git-blame--data buffer-file-name))
         (now  (float-time))
         (width 0))
    (unless (and data (> (hash-table-count data) 0))
      (user-error "Keine Blame-Daten -- Datei nicht in Git oder nicht committet"))
    (setq +git-blame--line-data data)
    (save-excursion
      (goto-char (point-min))
      (let ((line 1))
        (while (not (eobp))
          (let ((d (gethash line data)))
            (when d
              (let* ((epoch (plist-get d :epoch))
                     (days  (if epoch (/ (- now epoch) 86400.0) 99999))
                     (uncommitted (string-match-p "\\`0+\\'" (plist-get d :hash)))
                     (color (if uncommitted "#e0e0e0" (+git-blame--age-color days)))
                     (str   (if uncommitted
                                (format "%-7s %-16s %-10s " "•••••••" "(lokal)" "")
                              (format "%-7s %-16s %s "
                                      (plist-get d :hash)
                                      (+git-blame--short-author (plist-get d :author))
                                      (if epoch (format-time-string "%Y-%m-%d" epoch) "          "))))
                     (disp  (propertize str 'face (list :foreground color)))
                     (ov    (make-overlay (line-beginning-position) (line-beginning-position))))
                (setq width (max width (length str)))
                (overlay-put ov 'before-string
                             (propertize " " 'display (list (list 'margin 'left-margin) disp)))
                (overlay-put ov '+git-blame t)
                (push ov +git-blame--overlays))))
          (forward-line 1)
          (setq line (1+ line)))))
    (setq +git-blame--old-margin left-margin-width)
    (setq-local left-margin-width (1+ width))
    (+git-blame-inline--refresh-margins)))

(defun +git-blame-inline--refresh-margins (&rest _)
  "left-margin-width auf alle Fenster dieses Buffers anwenden (Redisplay)."
  (when (bound-and-true-p +git-blame-inline-mode)
    (dolist (win (get-buffer-window-list (current-buffer) nil t))
      (set-window-margins win left-margin-width (cdr (window-margins win))))))

(defun +git-blame-inline--enable ()
  (unless buffer-file-name (user-error "Kein dateibasierter Buffer"))
  (setq +git-blame--old-ro buffer-read-only
        +git-blame--overlays nil)
  (+git-blame-inline--apply)
  (add-hook 'window-configuration-change-hook #'+git-blame-inline--refresh-margins nil t)
  (setq buffer-read-only t)
  (message "Inline-Blame AN -- RET: Commit der Zeile ansehen, q / SPC g B: aus"))

(defun +git-blame-inline--disable ()
  (mapc #'delete-overlay +git-blame--overlays)
  (setq +git-blame--overlays nil
        +git-blame--line-data nil)
  (remove-hook 'window-configuration-change-hook #'+git-blame-inline--refresh-margins t)
  (when +git-blame--old-margin
    (setq-local left-margin-width +git-blame--old-margin))
  (dolist (win (get-buffer-window-list (current-buffer) nil t))
    (set-window-margins win left-margin-width (cdr (window-margins win))))
  (setq buffer-read-only +git-blame--old-ro)
  (message "Inline-Blame AUS"))

(define-minor-mode +git-blame-inline-mode
  "Inline Git Blame/Annotate im selben Buffer (linke Margin, Alters-Heatmap)."
  :lighter " Blame"
  :keymap (make-sparse-keymap)
  (if +git-blame-inline-mode
      (+git-blame-inline--enable)
    (+git-blame-inline--disable)))

;;;###autoload
(defun +git/blame-inline-show-commit ()
  "Commit-Diff des Commits der AKTUELLEN Zeile anzeigen (aus der Inline-Blame-Margin)."
  (interactive)
  (let* ((d    (and +git-blame--line-data
                    (gethash (line-number-at-pos) +git-blame--line-data)))
         (hash (plist-get d :hash)))
    (cond
     ((or (null hash) (string-match-p "\\`0+\\'" hash))
      (message "Diese Zeile ist noch nicht committet"))
     ((fboundp 'magit-show-commit) (magit-show-commit hash))
     (t (vc-print-log-internal 'Git (list buffer-file-name) hash nil 1)))))

(map! :map +git-blame-inline-mode-map
      :n "RET" #'+git/blame-inline-show-commit
      :n "q"   #'+git-blame-inline-mode)

(defun +git-blame--short-author (a)
  "Autornamen fuer die Blame-Margin auf feste Breite kuerzen."
  (let ((a (or a "?")))
    (if (> (length a) 15) (concat (substring a 0 14) "…") a)))
