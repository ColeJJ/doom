;;; rose-pine-moon-theme.el --- Rose Pine Moon color theme for Emacs -*- lexical-binding: t; -*-

;; Author: (lokal fuer Doom angelegt)
;; URL: https://rosepinetheme.com
;; Version: 1.0

;;; Commentary:
;;
;; Portierung der Rose-Pine-"Moon"-Variante nach Emacs, angelehnt an ThePrimeagens
;; neovim-Setup (rose-pine/neovim):
;;
;;   require('rose-pine').setup({ disable_background = true,
;;                                styles = { italic = false } })
;;
;; Umsetzung hier:
;;   - `styles.italic = false' -> NIRGENDS Kursivschrift (auch Kommentare gerade).
;;   - `disable_background = true' -> im TERMINAL uebernimmt der vorhandene Hook
;;     `+tty/inherit-terminal-background' (config.el) den iTerm2-Hintergrund. Im GUI
;;     nutzt das Theme den echten Moon-Hintergrund (#232136), damit es korrekt
;;     aussieht. Fuer einen komplett transparenten GUI-Hintergrund die `default'-
;;     bzw. Frame-Hintergrundfarbe entfernen (siehe Kommentar am Dateiende).
;;
;; Offizielle Rose-Pine-Moon-Palette (https://rosepinetheme.com/palette/):
;;   base #232136 surface #2a273f overlay #393552
;;   muted #6e6a86 subtle #908caa text #e0def4
;;   love #eb6f92 gold #f6c177 rose #ea9a97
;;   pine #3e8fb0 foam #9ccfd8 iris #c4a7e7
;;   highlight-low #2a283e highlight-med #44415a highlight-high #56526e

;;; Code:

(deftheme rose-pine-moon
  "Rose Pine Moon -- weiche, gedaempfte Dark-Variante (ohne Kursivschrift).")

(let ((base        "#232136")
      (surface     "#2a273f")
      (overlay     "#393552")
      (muted       "#6e6a86")
      (subtle      "#908caa")
      (text        "#e0def4")
      (love        "#eb6f92")
      (love-dim    "#b4637a")
      (gold        "#f6c177")
      (rose        "#ea9a97")
      (pine        "#3e8fb0")
      (foam        "#9ccfd8")
      (iris        "#c4a7e7")
      (leaf        "#95b1ac")
      (hl-low      "#2a283e")
      (hl-med      "#44415a")
      (hl-high     "#56526e"))

  (custom-theme-set-variables
   'rose-pine-moon
   '(frame-background-mode (quote dark)))

  (custom-theme-set-faces
   'rose-pine-moon

   ;; ---- Basis / Uncategorized ----
   `(default        ((t (:foreground ,text :background ,base))))
   `(cursor         ((t (:background ,text))))
   `(region         ((t (:background ,hl-med :extend t))))
   `(secondary-selection ((t (:background ,hl-low :extend t))))
   `(highlight      ((t (:background ,overlay))))
   `(hl-line        ((t (:background ,surface :extend t))))
   `(fringe         ((t (:background ,base :foreground ,muted))))
   `(vertical-border ((t (:foreground ,overlay))))
   `(window-divider ((t (:foreground ,overlay))))
   `(window-divider-first-pixel ((t (:foreground ,overlay))))
   `(window-divider-last-pixel  ((t (:foreground ,overlay))))
   `(minibuffer-prompt ((t (:foreground ,foam :weight bold))))
   `(shadow         ((t (:foreground ,muted))))
   `(link           ((t (:foreground ,foam :underline t))))
   `(link-visited   ((t (:foreground ,iris :underline t))))
   `(match          ((t (:background ,hl-high :foreground ,text))))
   `(error          ((t (:foreground ,love :weight bold))))
   `(warning        ((t (:foreground ,gold :weight bold))))
   `(success        ((t (:foreground ,leaf :weight bold))))
   `(escape-glyph   ((t (:foreground ,iris))))
   `(trailing-whitespace ((t (:background ,love-dim))))
   `(tooltip        ((t (:background ,overlay :foreground ,text))))
   `(fill-column-indicator ((t (:foreground ,overlay))))

   ;; ---- Font Lock (Syntax) -- exakt nach rose-pine/neovim, KEINE Kursivschrift ----
   ;; Wichtig: rose-pine faerbt Kommentare mit `subtle' (heller Lavendel-Grau), NICHT
   ;; mit dem dunkleren `muted'. Booleans = rose, Konstanten/Zahlen/Strings = gold,
   ;; Keywords = pine, Typen/Properties = foam, Funktionen = rose, PreProc/Attribute = iris.
   `(font-lock-builtin-face           ((t (:foreground ,love))))          ; @variable.builtin (this/self)
   `(font-lock-comment-face           ((t (:foreground ,subtle :slant normal))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,subtle :slant normal))))
   `(font-lock-doc-face               ((t (:foreground ,subtle :slant normal))))
   `(font-lock-doc-markup-face        ((t (:foreground ,foam :slant normal))))
   `(font-lock-string-face            ((t (:foreground ,gold))))
   `(font-lock-regexp-face            ((t (:foreground ,iris))))          ; @string.regexp
   `(font-lock-escape-face            ((t (:foreground ,pine))))          ; @string.escape
   `(font-lock-keyword-face           ((t (:foreground ,pine))))
   `(font-lock-constant-face          ((t (:foreground ,gold))))
   `(font-lock-function-name-face     ((t (:foreground ,rose))))
   `(font-lock-function-call-face     ((t (:foreground ,rose))))
   `(font-lock-variable-name-face     ((t (:foreground ,text))))
   `(font-lock-variable-use-face      ((t (:foreground ,text))))
   `(font-lock-type-face              ((t (:foreground ,foam))))
   `(font-lock-preprocessor-face      ((t (:foreground ,iris))))         ; PreProc/Define/Macro
   `(font-lock-negation-char-face     ((t (:foreground ,subtle))))
   `(font-lock-warning-face           ((t (:foreground ,gold :weight bold))))
   `(font-lock-number-face            ((t (:foreground ,gold))))
   `(font-lock-operator-face          ((t (:foreground ,subtle))))
   `(font-lock-property-name-face     ((t (:foreground ,foam))))          ; @property/@field
   `(font-lock-property-use-face      ((t (:foreground ,foam))))
   `(font-lock-punctuation-face       ((t (:foreground ,subtle))))
   `(font-lock-delimiter-face         ((t (:foreground ,subtle))))
   `(font-lock-misc-punctuation-face  ((t (:foreground ,subtle))))
   `(font-lock-bracket-face           ((t (:foreground ,subtle))))

   ;; ---- Zeilennummern ----
   `(line-number              ((t (:inherit default :foreground ,muted))))
   `(line-number-current-line ((t (:inherit default :foreground ,text :weight bold))))

   ;; ---- Mode line / doom-modeline ----
   `(mode-line          ((t (:background ,overlay :foreground ,text :box nil))))
   `(mode-line-active   ((t (:background ,overlay :foreground ,text :box nil))))
   `(mode-line-inactive ((t (:background ,surface :foreground ,muted :box nil))))
   `(mode-line-buffer-id ((t (:foreground ,rose :weight bold))))
   `(mode-line-emphasis  ((t (:foreground ,foam))))
   `(mode-line-highlight ((t (:background ,hl-med))))
   `(doom-modeline-buffer-file        ((t (:foreground ,text :weight bold))))
   `(doom-modeline-buffer-modified    ((t (:foreground ,love :weight bold))))
   `(doom-modeline-buffer-path        ((t (:foreground ,subtle))))
   `(doom-modeline-project-dir        ((t (:foreground ,foam :weight bold))))
   `(doom-modeline-info               ((t (:foreground ,foam))))
   `(doom-modeline-warning            ((t (:foreground ,gold))))
   `(doom-modeline-urgent             ((t (:foreground ,love))))
   `(doom-modeline-bar                ((t (:background ,iris))))
   `(doom-modeline-bar-inactive       ((t (:background ,surface))))
   `(doom-modeline-evil-normal-state  ((t (:foreground ,foam))))
   `(doom-modeline-evil-insert-state  ((t (:foreground ,gold))))
   `(doom-modeline-evil-visual-state  ((t (:foreground ,iris))))
   `(doom-modeline-evil-replace-state ((t (:foreground ,love))))

   ;; ---- Suche ----
   `(isearch        ((t (:background ,gold :foreground ,base :weight bold))))
   `(isearch-fail   ((t (:background ,love :foreground ,base))))
   `(lazy-highlight ((t (:background ,hl-high :foreground ,text))))
   `(evil-ex-search ((t (:background ,gold :foreground ,base))))
   `(anzu-mode-line ((t (:foreground ,iris :weight bold))))

   ;; ---- Klammern ----
   `(show-paren-match    ((t (:background ,hl-high :foreground ,gold :weight bold))))
   `(show-paren-mismatch ((t (:background ,love :foreground ,base :weight bold))))
   `(rainbow-delimiters-depth-1-face ((t (:foreground ,pine))))
   `(rainbow-delimiters-depth-2-face ((t (:foreground ,iris))))
   `(rainbow-delimiters-depth-3-face ((t (:foreground ,gold))))
   `(rainbow-delimiters-depth-4-face ((t (:foreground ,leaf))))
   `(rainbow-delimiters-depth-5-face ((t (:foreground ,rose))))
   `(rainbow-delimiters-depth-6-face ((t (:foreground ,love))))
   `(rainbow-delimiters-unmatched-face ((t (:foreground ,love :weight bold))))

   ;; ---- Vertico / Corfu / Marginalia / Orderless ----
   `(vertico-current      ((t (:background ,hl-med :extend t))))
   `(corfu-default        ((t (:background ,surface :foreground ,text))))
   `(corfu-current        ((t (:background ,hl-med :foreground ,text))))
   `(corfu-bar            ((t (:background ,iris))))
   `(corfu-border         ((t (:background ,overlay))))
   `(marginalia-key       ((t (:foreground ,gold))))
   `(marginalia-documentation ((t (:foreground ,muted))))
   `(orderless-match-face-0 ((t (:foreground ,foam :weight bold))))
   `(orderless-match-face-1 ((t (:foreground ,iris :weight bold))))
   `(orderless-match-face-2 ((t (:foreground ,gold :weight bold))))
   `(orderless-match-face-3 ((t (:foreground ,rose :weight bold))))
   `(completions-common-part ((t (:foreground ,foam :weight bold))))
   `(completions-annotations ((t (:foreground ,muted))))

   ;; ---- company ----
   `(company-tooltip            ((t (:background ,surface :foreground ,text))))
   `(company-tooltip-selection  ((t (:background ,hl-med))))
   `(company-tooltip-common     ((t (:foreground ,foam :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,muted))))
   `(company-scrollbar-bg       ((t (:background ,overlay))))
   `(company-scrollbar-fg       ((t (:background ,iris))))
   `(company-preview            ((t (:foreground ,muted))))
   `(company-preview-common     ((t (:foreground ,foam))))

   ;; ---- Diagnostics (flycheck / flymake / lsp) ----
   `(flycheck-error   ((t (:underline (:style wave :color ,love)))))
   `(flycheck-warning ((t (:underline (:style wave :color ,gold)))))
   `(flycheck-info    ((t (:underline (:style wave :color ,foam)))))
   `(flymake-error    ((t (:underline (:style wave :color ,love)))))
   `(flymake-warning  ((t (:underline (:style wave :color ,gold)))))
   `(flymake-note     ((t (:underline (:style wave :color ,foam)))))
   `(lsp-ui-sideline-code-action ((t (:foreground ,gold))))
   `(lsp-face-highlight-textual  ((t (:background ,hl-med))))
   `(lsp-face-highlight-read     ((t (:background ,hl-med))))
   `(lsp-face-highlight-write    ((t (:background ,hl-high))))
   `(lsp-headerline-breadcrumb-path-face ((t (:foreground ,subtle))))
   `(lsp-headerline-breadcrumb-symbols-face ((t (:foreground ,text))))

   ;; ---- Diff / ediff ----
   `(diff-added     ((t (:foreground ,foam :background ,hl-low :extend t))))  ; git_add = foam
   `(diff-removed   ((t (:foreground ,love :background ,hl-low :extend t))))  ; git_delete = love
   `(diff-changed   ((t (:foreground ,rose :background ,hl-low :extend t))))  ; git_change = rose
   `(diff-header    ((t (:foreground ,iris :weight bold))))
   `(diff-file-header ((t (:foreground ,text :weight bold))))
   `(diff-hunk-header ((t (:foreground ,subtle :background ,surface))))
   `(ediff-current-diff-A ((t (:background ,hl-low))))
   `(ediff-current-diff-B ((t (:background ,hl-low))))
   `(ediff-fine-diff-A ((t (:background ,love-dim :foreground ,text))))
   `(ediff-fine-diff-B ((t (:background ,pine :foreground ,text))))

   ;; ---- Magit ----
   `(magit-section-heading     ((t (:foreground ,gold :weight bold))))
   `(magit-section-highlight   ((t (:background ,surface :extend t))))
   `(magit-branch-local        ((t (:foreground ,foam :weight bold))))
   `(magit-branch-remote       ((t (:foreground ,iris :weight bold))))
   `(magit-tag                 ((t (:foreground ,gold))))
   `(magit-hash                ((t (:foreground ,muted))))
   `(magit-log-author          ((t (:foreground ,rose))))
   `(magit-log-date            ((t (:foreground ,muted))))
   `(magit-diff-added          ((t (:foreground ,foam :background ,hl-low :extend t))))
   `(magit-diff-added-highlight ((t (:foreground ,foam :background ,surface :extend t))))
   `(magit-diff-removed        ((t (:foreground ,love :background ,hl-low :extend t))))
   `(magit-diff-removed-highlight ((t (:foreground ,love :background ,surface :extend t))))
   `(magit-diff-context        ((t (:foreground ,subtle :extend t))))
   `(magit-diff-context-highlight ((t (:foreground ,text :background ,surface :extend t))))
   `(magit-diff-hunk-heading   ((t (:foreground ,subtle :background ,overlay :extend t))))
   `(magit-diff-hunk-heading-highlight ((t (:foreground ,text :background ,hl-med :extend t))))

   ;; ---- Org Mode ----
   `(org-level-1     ((t (:foreground ,iris :weight bold :height 1.15))))
   `(org-level-2     ((t (:foreground ,foam :weight bold :height 1.1))))
   `(org-level-3     ((t (:foreground ,rose :weight bold))))
   `(org-level-4     ((t (:foreground ,gold :weight bold))))
   `(org-level-5     ((t (:foreground ,pine))))
   `(org-level-6     ((t (:foreground ,love))))
   `(org-level-7     ((t (:foreground ,subtle))))
   `(org-level-8     ((t (:foreground ,muted))))
   `(org-document-title ((t (:foreground ,gold :weight bold :height 1.3))))
   `(org-todo        ((t (:foreground ,love :weight bold))))
   `(org-done        ((t (:foreground ,foam :weight bold))))
   `(org-headline-done ((t (:foreground ,muted))))
   `(org-link        ((t (:foreground ,foam :underline t))))
   `(org-code        ((t (:foreground ,gold))))
   `(org-verbatim    ((t (:foreground ,rose))))
   `(org-block       ((t (:background ,surface :extend t))))
   `(org-block-begin-line ((t (:foreground ,muted :background ,hl-low :extend t))))
   `(org-block-end-line   ((t (:foreground ,muted :background ,hl-low :extend t))))
   `(org-table       ((t (:foreground ,subtle))))
   `(org-date        ((t (:foreground ,iris :underline t))))
   `(org-special-keyword ((t (:foreground ,muted))))
   `(org-drawer      ((t (:foreground ,muted))))
   `(org-agenda-structure ((t (:foreground ,iris :weight bold))))
   `(org-agenda-date  ((t (:foreground ,foam))))
   `(org-agenda-date-today ((t (:foreground ,gold :weight bold))))
   `(org-scheduled    ((t (:foreground ,foam))))
   `(org-scheduled-today ((t (:foreground ,text))))
   `(org-warning      ((t (:foreground ,love :weight bold))))

   ;; ---- Dired / Treemacs ----
   `(dired-directory ((t (:foreground ,foam :weight bold))))
   `(dired-symlink   ((t (:foreground ,iris))))
   `(dired-ignored   ((t (:foreground ,muted))))
   `(treemacs-root-face ((t (:foreground ,gold :weight bold :height 1.1))))
   `(treemacs-directory-face ((t (:foreground ,subtle))))
   `(treemacs-file-face ((t (:foreground ,text))))
   `(treemacs-git-modified-face ((t (:foreground ,rose))))
   `(treemacs-git-added-face ((t (:foreground ,foam))))
   `(treemacs-git-untracked-face ((t (:foreground ,subtle))))

   ;; ---- Tab bar / Tab line ----
   `(tab-bar          ((t (:background ,surface :foreground ,subtle))))
   `(tab-bar-tab      ((t (:background ,base :foreground ,gold :weight bold))))
   `(tab-bar-tab-inactive ((t (:background ,surface :foreground ,muted))))

   ;; ---- which-key ----
   `(which-key-key-face ((t (:foreground ,gold :weight bold))))
   `(which-key-command-description-face ((t (:foreground ,text))))
   `(which-key-group-description-face ((t (:foreground ,foam))))
   `(which-key-separator-face ((t (:foreground ,muted))))

   ;; ---- ANSI / term Farben ----
   `(term-color-black   ((t (:foreground ,overlay :background ,overlay))))
   `(term-color-red     ((t (:foreground ,love :background ,love))))
   `(term-color-green   ((t (:foreground ,foam :background ,foam))))
   `(term-color-yellow  ((t (:foreground ,gold :background ,gold))))
   `(term-color-blue    ((t (:foreground ,pine :background ,pine))))
   `(term-color-magenta ((t (:foreground ,iris :background ,iris))))
   `(term-color-cyan    ((t (:foreground ,foam :background ,foam))))
   `(term-color-white   ((t (:foreground ,text :background ,text))))

   ;; ---- Doom Dashboard / Startfenster ----
   `(doom-dashboard-banner ((t (:foreground ,iris))))
   `(doom-dashboard-menu-title ((t (:foreground ,foam :weight bold))))
   `(doom-dashboard-menu-desc  ((t (:foreground ,gold))))
   `(doom-dashboard-footer     ((t (:foreground ,muted))))
   `(doom-dashboard-loaded     ((t (:foreground ,muted)))))

  (custom-theme-set-variables
   'rose-pine-moon
   `(ansi-color-names-vector
     [,overlay ,love ,foam ,gold ,pine ,iris ,foam ,text])))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'rose-pine-moon)

;; Hinweis "disable_background = true" fuer das GUI (voll transparent):
;;   Im Terminal wird der Hintergrund bereits durch `+tty/inherit-terminal-background'
;;   (config.el) an iTerm2 abgegeben. Fuer einen transparenten GUI-Frame zusaetzlich
;;   in config.el z.B.:
;;     (add-to-list 'default-frame-alist '(alpha-background . 90))
;;   oder die default-Hintergrundfarbe entfernen. Standard hier: solider Moon-BG.

;; Local Variables:
;; no-byte-compile: t
;; indent-tabs-mode: nil
;; eval: (when (fboundp 'rainbow-mode) (rainbow-mode +1))
;; End:

;;; rose-pine-moon-theme.el ends here
