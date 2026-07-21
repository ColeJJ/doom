;;; tj-theme.el --- TJ DeVries' colorbuddy-Theme, portiert nach Emacs -*- lexical-binding: t; -*-

;; Author: (lokal fuer Doom angelegt)
;; Version: 1.0

;;; Commentary:
;;
;; Nachbau des colorbuddy-Themes von TJ DeVries (neovim) fuer Emacs/Doom.
;;
;; Umgesetzte Besonderheiten aus dem Original:
;;   - Dunkler, blaustichiger Hintergrund #0F111A, Text als "superwhite" #E0E0E0.
;;   - Funktionen GELB + fett, Keywords VIOLETT, Typen VIOLETT + KURSIV,
;;     Strings GRUEN, Zahlen/Bedingungen ROT, Konstanten/Booleans ORANGE,
;;     Kommentare hellgrau + KURSIV (Original: `s.italic').
;;   - Auffaellige BLAUE Statusline (StatusLine = gray2 auf blau).
;;   - Auswahl-Popup (PMenuSel) mit hellgelbem Hintergrund.
;;
;; colorbuddy-Grautoene (aus colorbuddy/color.lua):
;;   gray0 #111111  gray1 #282a2e  gray2 #373b41  gray3 #969896
;;   gray4 #b4b7b4  gray5 #c5c8c6  gray6 #e0e0e0  gray7 #ffffff
;; Abgeleitete Farben (`:light()' = +0.1 / `:dark(x)' = -x auf HSL-Helligkeit):
;;   gray3:light() #b0b1b0  yellow:light() #fbfead  purple:light() #a992cd
;;   purple:light():light() #c5b5dd  red:light() #d98c8c  red:light():light() #e6b2b2
;;   blue:dark(0.3) #38556e  gray1:light() #404349

;;; Code:

(deftheme tj
  "TJ DeVries' colorbuddy-Theme (gelbe Funktionen, blaue Statusline).")

(let ((bg          "#0F111A")   ; background
      (fg          "#E0E0E0")   ; superwhite (Normal fg)
      (white       "#f2e5bc")
      (softwhite   "#ebdbb2")
      (red         "#cc6666")
      (red-l       "#d98c8c")   ; red:light()
      (red-ll      "#e6b2b2")   ; red:light():light()  (Operator)
      (green       "#99cc99")
      (yellow      "#f8fe7a")
      (yellow-l    "#fbfead")   ; yellow:light()  (PMenuSel bg)
      (blue        "#81a2be")
      (blue-d      "#38556e")   ; blue:dark(0.3)  (Visual bg)
      (aqua        "#8ec07c")
      (cyan        "#8abeb7")
      (purple      "#8e6fbd")
      (purple-l    "#a992cd")   ; purple:light()  (Special)
      (purple-ll   "#c5b5dd")   ; purple:light():light()  (@variable.builtin)
      (violet      "#b294bb")
      (orange      "#de935f")
      (brown       "#a3685a")
      (seagreen    "#698b69")
      (teal        "#018080")
      (gray0       "#111111")
      (gray1       "#282a2e")
      (gray1-l     "#404349")   ; gray1:light()  (StatusLineNC bg)
      (gray2       "#373b41")
      (gray3       "#969896")
      (gray3-l     "#b0b1b0")   ; gray3:light()  (Comment)
      (gray4       "#b4b7b4")
      (gray5       "#c5c8c6")
      (gray6       "#e0e0e0")
      (gray7       "#ffffff"))

  (custom-theme-set-variables
   'tj
   '(frame-background-mode (quote dark)))

  (custom-theme-set-faces
   'tj

   ;; ---- Basis / Editor ----
   `(default        ((t (:foreground ,fg :background ,bg))))
   `(cursor         ((t (:background ,white))))
   `(region         ((t (:background ,blue-d :extend t))))                 ; Visual
   `(secondary-selection ((t (:background ,gray1 :extend t))))
   `(highlight      ((t (:background ,blue-d))))
   `(hl-line        ((t (:background ,gray1 :extend t))))
   `(fringe         ((t (:background ,bg :foreground ,gray3))))
   `(vertical-border ((t (:foreground ,gray2))))
   `(window-divider ((t (:foreground ,gray2))))
   `(window-divider-first-pixel ((t (:foreground ,gray2))))
   `(window-divider-last-pixel  ((t (:foreground ,gray2))))
   `(minibuffer-prompt ((t (:foreground ,blue :weight bold))))
   `(shadow         ((t (:foreground ,gray3))))
   `(link           ((t (:foreground ,blue :underline t))))
   `(link-visited   ((t (:foreground ,purple-l :underline t))))
   `(match          ((t (:background ,blue-d :foreground ,fg))))
   `(error          ((t (:foreground ,red-l :weight bold))))
   `(warning        ((t (:foreground ,orange :weight bold))))
   `(success        ((t (:foreground ,green :weight bold))))
   `(escape-glyph   ((t (:foreground ,orange))))
   `(trailing-whitespace ((t (:background ,red))))
   `(tooltip        ((t (:background ,gray1 :foreground ,fg))))
   `(fill-column-indicator ((t (:foreground ,gray1))))

   ;; ---- Font Lock (Syntax) -- nach dem colorbuddy-Original ----
   `(font-lock-comment-face           ((t (:foreground ,gray3-l :slant italic))))   ; Comment (italic!)
   `(font-lock-comment-delimiter-face ((t (:foreground ,gray3-l :slant italic))))
   `(font-lock-doc-face               ((t (:foreground ,gray3-l :slant italic))))
   `(font-lock-doc-markup-face        ((t (:foreground ,cyan))))
   `(font-lock-string-face            ((t (:foreground ,green))))                    ; String
   `(font-lock-regexp-face            ((t (:foreground ,green))))
   `(font-lock-escape-face            ((t (:foreground ,orange))))
   `(font-lock-keyword-face           ((t (:foreground ,violet))))                   ; Keyword
   `(font-lock-constant-face          ((t (:foreground ,orange :weight bold))))      ; Constant
   `(font-lock-builtin-face           ((t (:foreground ,purple-l :weight bold))))    ; Special
   `(font-lock-function-name-face     ((t (:foreground ,yellow :weight bold))))      ; Function
   `(font-lock-function-call-face     ((t (:foreground ,yellow :weight bold))))      ; @function.call
   `(font-lock-variable-name-face     ((t (:foreground ,fg))))                       ; @variable
   `(font-lock-variable-use-face      ((t (:foreground ,fg))))
   `(font-lock-type-face              ((t (:foreground ,violet :slant italic))))     ; Type (italic!)
   `(font-lock-preprocessor-face      ((t (:foreground ,cyan))))                     ; Define/Include
   `(font-lock-number-face            ((t (:foreground ,red))))                      ; Number
   `(font-lock-negation-char-face     ((t (:foreground ,red-ll))))
   `(font-lock-warning-face           ((t (:foreground ,red-l :weight bold))))
   `(font-lock-operator-face          ((t (:foreground ,red-ll))))                   ; Operator
   `(font-lock-property-name-face     ((t (:foreground ,fg))))
   `(font-lock-property-use-face      ((t (:foreground ,fg))))
   `(font-lock-punctuation-face       ((t (:foreground ,fg))))
   `(font-lock-delimiter-face         ((t (:foreground ,fg))))
   `(font-lock-misc-punctuation-face  ((t (:foreground ,fg))))
   `(font-lock-bracket-face           ((t (:foreground ,fg))))
   ;; builtin/eingebaute Variablen (this/self) -> hellstes Violett (@variable.builtin):
   `(tree-sitter-hl-face:variable.builtin ((t (:foreground ,purple-ll))))

   ;; ---- Zeilennummern ----
   `(line-number              ((t (:inherit default :foreground ,gray3))))
   `(line-number-current-line ((t (:inherit default :foreground ,gray6 :weight bold))))

   ;; ---- Mode line / Statusline (blau, wie im Original) ----
   `(mode-line          ((t (:background ,blue :foreground ,gray2 :box nil))))
   `(mode-line-active   ((t (:background ,blue :foreground ,gray2 :box nil))))
   `(mode-line-inactive ((t (:background ,gray1-l :foreground ,gray3 :box nil))))
   `(mode-line-buffer-id ((t (:foreground ,gray0 :weight bold))))
   `(mode-line-emphasis  ((t (:foreground ,gray0 :weight bold))))
   `(mode-line-highlight ((t (:background ,blue-d))))
   `(doom-modeline-buffer-file        ((t (:foreground ,gray2 :weight bold))))
   `(doom-modeline-buffer-modified    ((t (:foreground ,red :weight bold))))
   `(doom-modeline-buffer-path        ((t (:foreground ,gray2))))
   `(doom-modeline-project-dir        ((t (:foreground ,gray0 :weight bold))))
   `(doom-modeline-info               ((t (:foreground ,gray2))))
   `(doom-modeline-warning            ((t (:foreground ,orange))))
   `(doom-modeline-urgent             ((t (:foreground ,red))))
   `(doom-modeline-bar                ((t (:background ,yellow))))
   `(doom-modeline-bar-inactive       ((t (:background ,gray1-l))))
   `(doom-modeline-evil-normal-state  ((t (:foreground ,gray2))))
   `(doom-modeline-evil-insert-state  ((t (:foreground ,gray0 :weight bold))))
   `(doom-modeline-evil-visual-state  ((t (:foreground ,gray0 :weight bold))))
   `(doom-modeline-evil-replace-state ((t (:foreground ,gray0 :weight bold))))

   ;; ---- Suche ----
   `(isearch        ((t (:background ,yellow :foreground ,gray0 :weight bold))))
   `(isearch-fail   ((t (:background ,red :foreground ,gray0))))
   `(lazy-highlight ((t (:background ,blue-d :foreground ,fg))))
   `(evil-ex-search ((t (:background ,yellow :foreground ,gray0))))

   ;; ---- Klammern ----
   `(show-paren-match    ((t (:background ,blue-d :foreground ,yellow :weight bold))))
   `(show-paren-mismatch ((t (:background ,red :foreground ,gray0 :weight bold))))
   `(rainbow-delimiters-depth-1-face ((t (:foreground ,yellow))))
   `(rainbow-delimiters-depth-2-face ((t (:foreground ,violet))))
   `(rainbow-delimiters-depth-3-face ((t (:foreground ,green))))
   `(rainbow-delimiters-depth-4-face ((t (:foreground ,orange))))
   `(rainbow-delimiters-depth-5-face ((t (:foreground ,cyan))))
   `(rainbow-delimiters-depth-6-face ((t (:foreground ,blue))))
   `(rainbow-delimiters-depth-7-face ((t (:foreground ,red))))
   `(rainbow-delimiters-unmatched-face ((t (:foreground ,red :weight bold))))

   ;; ---- Vertico / Corfu / Marginalia / Orderless / Popup (PMenu) ----
   `(vertico-current      ((t (:background ,blue-d :extend t))))
   `(corfu-default        ((t (:background ,bg :foreground ,gray4))))       ; PMenu
   `(corfu-current        ((t (:background ,yellow-l :foreground ,gray0)))) ; PMenuSel
   `(corfu-bar            ((t (:background ,gray4))))                       ; PMenuThumb
   `(corfu-border         ((t (:background ,gray1))))
   `(marginalia-key       ((t (:foreground ,yellow))))
   `(marginalia-documentation ((t (:foreground ,gray3))))
   `(orderless-match-face-0 ((t (:foreground ,yellow :weight bold))))
   `(orderless-match-face-1 ((t (:foreground ,violet :weight bold))))
   `(orderless-match-face-2 ((t (:foreground ,green :weight bold))))
   `(orderless-match-face-3 ((t (:foreground ,orange :weight bold))))
   `(completions-common-part ((t (:foreground ,yellow :weight bold))))
   `(completions-annotations ((t (:foreground ,gray3))))

   ;; ---- company (PMenu-Farben) ----
   `(company-tooltip            ((t (:background ,bg :foreground ,gray4))))
   `(company-tooltip-selection  ((t (:background ,yellow-l :foreground ,gray0))))
   `(company-tooltip-common     ((t (:foreground ,yellow :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,gray3))))
   `(company-scrollbar-bg       ((t (:background ,gray0))))
   `(company-scrollbar-fg       ((t (:background ,gray4))))
   `(company-preview            ((t (:foreground ,gray3))))
   `(company-preview-common     ((t (:foreground ,yellow))))

   ;; ---- Diagnostics (flycheck / flymake / lsp) ----
   `(flycheck-error   ((t (:underline (:style wave :color ,red)))))
   `(flycheck-warning ((t (:underline (:style wave :color ,orange)))))
   `(flycheck-info    ((t (:underline (:style wave :color ,blue)))))
   `(flymake-error    ((t (:underline (:style wave :color ,red)))))
   `(flymake-warning  ((t (:underline (:style wave :color ,orange)))))
   `(flymake-note     ((t (:underline (:style wave :color ,blue)))))
   `(lsp-ui-sideline-code-action ((t (:foreground ,yellow))))
   `(lsp-face-highlight-textual  ((t (:background ,blue-d))))
   `(lsp-face-highlight-read     ((t (:background ,blue-d))))
   `(lsp-face-highlight-write    ((t (:background ,gray2))))
   `(lsp-headerline-breadcrumb-path-face ((t (:foreground ,gray3))))
   `(lsp-headerline-breadcrumb-symbols-face ((t (:foreground ,fg))))

   ;; ---- Diff / ediff / Magit ----
   `(diff-added     ((t (:foreground ,green :background ,gray1 :extend t))))
   `(diff-removed   ((t (:foreground ,red :background ,gray1 :extend t))))
   `(diff-changed   ((t (:foreground ,orange :background ,gray1 :extend t))))
   `(diff-header    ((t (:foreground ,blue :weight bold))))
   `(diff-file-header ((t (:foreground ,fg :weight bold))))
   `(diff-hunk-header ((t (:foreground ,gray3 :background ,gray1))))
   `(ediff-current-diff-A ((t (:background ,gray1))))
   `(ediff-current-diff-B ((t (:background ,gray1))))
   `(ediff-fine-diff-A ((t (:background ,red :foreground ,gray0))))
   `(ediff-fine-diff-B ((t (:background ,green :foreground ,gray0))))
   `(magit-section-heading     ((t (:foreground ,yellow :weight bold))))
   `(magit-section-highlight   ((t (:background ,gray1 :extend t))))
   `(magit-branch-local        ((t (:foreground ,blue :weight bold))))
   `(magit-branch-remote       ((t (:foreground ,green :weight bold))))
   `(magit-tag                 ((t (:foreground ,yellow))))
   `(magit-hash                ((t (:foreground ,gray3))))
   `(magit-log-author          ((t (:foreground ,orange))))
   `(magit-log-date            ((t (:foreground ,gray3))))
   `(magit-diff-added          ((t (:foreground ,green :background ,gray1 :extend t))))
   `(magit-diff-added-highlight ((t (:foreground ,green :background ,gray2 :extend t))))
   `(magit-diff-removed        ((t (:foreground ,red :background ,gray1 :extend t))))
   `(magit-diff-removed-highlight ((t (:foreground ,red :background ,gray2 :extend t))))
   `(magit-diff-context        ((t (:foreground ,gray3 :extend t))))
   `(magit-diff-context-highlight ((t (:foreground ,fg :background ,gray1 :extend t))))
   `(magit-diff-hunk-heading   ((t (:foreground ,gray3 :background ,gray1 :extend t))))
   `(magit-diff-hunk-heading-highlight ((t (:foreground ,fg :background ,gray2 :extend t))))

   ;; ---- Org Mode ----
   `(org-level-1     ((t (:foreground ,yellow :weight bold :height 1.15))))
   `(org-level-2     ((t (:foreground ,violet :weight bold :height 1.1))))
   `(org-level-3     ((t (:foreground ,green :weight bold))))
   `(org-level-4     ((t (:foreground ,orange :weight bold))))
   `(org-level-5     ((t (:foreground ,blue))))
   `(org-level-6     ((t (:foreground ,cyan))))
   `(org-level-7     ((t (:foreground ,aqua))))
   `(org-level-8     ((t (:foreground ,purple-l))))
   `(org-document-title ((t (:foreground ,yellow :weight bold :height 1.3))))
   `(org-todo        ((t (:foreground ,red :weight bold))))
   `(org-done        ((t (:foreground ,green :weight bold))))
   `(org-headline-done ((t (:foreground ,gray3))))
   `(org-link        ((t (:foreground ,blue :underline t))))
   `(org-code        ((t (:foreground ,orange))))
   `(org-verbatim    ((t (:foreground ,green))))
   `(org-block       ((t (:background ,gray1 :extend t))))
   `(org-block-begin-line ((t (:foreground ,gray3 :background ,gray1 :extend t))))
   `(org-block-end-line   ((t (:foreground ,gray3 :background ,gray1 :extend t))))
   `(org-table       ((t (:foreground ,blue))))
   `(org-date        ((t (:foreground ,cyan :underline t))))
   `(org-special-keyword ((t (:foreground ,gray3))))
   `(org-drawer      ((t (:foreground ,gray3))))
   `(org-agenda-structure ((t (:foreground ,violet :weight bold))))
   `(org-agenda-date  ((t (:foreground ,blue))))
   `(org-agenda-date-today ((t (:foreground ,yellow :weight bold))))
   `(org-scheduled    ((t (:foreground ,green))))
   `(org-scheduled-today ((t (:foreground ,fg))))
   `(org-warning      ((t (:foreground ,red :weight bold))))

   ;; ---- Dired / Treemacs ----
   `(dired-directory ((t (:foreground ,blue :weight bold))))
   `(dired-symlink   ((t (:foreground ,cyan))))
   `(dired-ignored   ((t (:foreground ,gray3))))
   `(treemacs-root-face ((t (:foreground ,yellow :weight bold :height 1.1))))
   `(treemacs-directory-face ((t (:foreground ,blue))))
   `(treemacs-file-face ((t (:foreground ,fg))))
   `(treemacs-git-modified-face ((t (:foreground ,orange))))
   `(treemacs-git-added-face ((t (:foreground ,green))))
   `(treemacs-git-untracked-face ((t (:foreground ,gray3))))

   ;; ---- Tab bar / Tab line ----
   `(tab-bar          ((t (:background ,gray3 :foreground ,softwhite))))   ; TabLineFill
   `(tab-bar-tab      ((t (:background ,bg :foreground ,yellow :weight bold))))
   `(tab-bar-tab-inactive ((t (:background ,gray3 :foreground ,softwhite))))
   `(tab-line         ((t (:background ,gray3 :foreground ,softwhite))))

   ;; ---- which-key ----
   `(which-key-key-face ((t (:foreground ,yellow :weight bold))))
   `(which-key-command-description-face ((t (:foreground ,fg))))
   `(which-key-group-description-face ((t (:foreground ,violet))))
   `(which-key-separator-face ((t (:foreground ,gray3))))

   ;; ---- ANSI / term Farben ----
   `(term-color-black   ((t (:foreground ,gray1 :background ,gray1))))
   `(term-color-red     ((t (:foreground ,red :background ,red))))
   `(term-color-green   ((t (:foreground ,green :background ,green))))
   `(term-color-yellow  ((t (:foreground ,yellow :background ,yellow))))
   `(term-color-blue    ((t (:foreground ,blue :background ,blue))))
   `(term-color-magenta ((t (:foreground ,violet :background ,violet))))
   `(term-color-cyan    ((t (:foreground ,cyan :background ,cyan))))
   `(term-color-white   ((t (:foreground ,gray6 :background ,gray6))))

   ;; ---- Doom Dashboard / Startfenster ----
   `(doom-dashboard-banner ((t (:foreground ,violet))))
   `(doom-dashboard-menu-title ((t (:foreground ,yellow :weight bold))))
   `(doom-dashboard-menu-desc  ((t (:foreground ,orange))))
   `(doom-dashboard-footer     ((t (:foreground ,gray3))))
   `(doom-dashboard-loaded     ((t (:foreground ,gray3)))))

  (custom-theme-set-variables
   'tj
   `(ansi-color-names-vector
     [,gray1 ,red ,green ,yellow ,blue ,violet ,cyan ,gray6])))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'tj)

;; Local Variables:
;; no-byte-compile: t
;; indent-tabs-mode: nil
;; eval: (when (fboundp 'rainbow-mode) (rainbow-mode +1))
;; End:

;;; tj-theme.el ends here
