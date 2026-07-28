;;; custom-obsidian-theme.el --- IntelliJ "Obsidian Custom" nach Emacs/Doom -*- lexical-binding: t; -*-

;; Author: (lokal fuer Doom angelegt)
;; Version: 1.0

;;; Commentary:
;;
;; Nachbau des IntelliJ-Farbschemas "Obsidian Custom Main" (parent: Darcula)
;; fuer Emacs/Doom. Alle Farben 1:1 aus der .icls uebernommen (IntelliJ speichert
;; Hex teils ohne fuehrende Null, hier auf 6 Stellen normalisiert, z.B. 10611 ->
;; 010611).
;;
;; Kernzuege des Originals:
;;   - Sehr dunkler, blau-schwarzer Hintergrund #010611, Text hellgrau #c9cccd.
;;   - Keywords GOLD (#e3d363), Strings/Zahlen GRUEN (#97cb8f / #a3bb97).
;;   - Funktions-DEKLARATION hellgold (#f8e1aa), Aufrufe/Methoden hellblau (#cadee8).
;;   - Typen/Klassen grau-gruen (#9ba69f), Felder/Variablen/Parameter grau-blau
;;     (#8e97a4), Konstanten VIOLETT (#716994, kursiv).
;;   - Kommentare gedaempftes Blaugrau (#293941, kursiv) -- bewusst dezent.
;;   - Operatoren/Klammern/Satzzeichen fast-weiss (#e0e0e7).
;;   - Fehler pink-rot (#ff4262), Warnungen blass-gelb (#d9c979).

;;; Code:

(deftheme custom-obsidian
  "IntelliJ 'Obsidian Custom' portiert nach Emacs/Doom (gold Keywords, sehr dunkler Grund).")

(let ((bg          "#010611")   ; TEXT/GUTTER/CONSOLE background
      (bg-line     "#05111D")   ; CARET_ROW (hl-line), folded, info hint
      (bg-sel      "#082C3C")   ; SELECTION_BACKGROUND
      (bg-sel2     "#0B364B")   ; SELECTED_INDENT_GUIDE (secondary)
      (border      "#08212F")   ; METHOD_SEPARATORS / diagram edge
      (indent      "#081826")   ; INDENT_GUIDE / right margin
      (fg          "#c9cccd")   ; TEXT foreground
      (fg-bright   "#e0e0e7")   ; Operatoren/Klammern/Satzzeichen
      (sel-fg      "#c2c2c2")   ; SELECTION_FOREGROUND
      (comment     "#293941")   ; Kommentare + Zeilennummern (gedaempft)
      (linenr      "#293941")
      (linenr-cur  "#4b666f")   ; LINE_NUMBER_ON_CARET_ROW
      (keyword     "#e3d363")   ; DEFAULT_KEYWORD (gold)
      (string      "#97cb8f")   ; DEFAULT_STRING (gruen)
      (number      "#a3bb97")   ; DEFAULT_NUMBER (gedaempftes gruen)
      (func-decl   "#f8e1aa")   ; DEFAULT_FUNCTION_DECLARATION (hellgold)
      (func-call   "#cadee8")   ; DEFAULT_FUNCTION_CALL/INSTANCE_METHOD (hellblau)
      (type        "#9ba69f")   ; DEFAULT_CLASS_NAME/INTERFACE/IDENTIFIER (grau-gruen)
      (field       "#8e97a4")   ; DEFAULT_INSTANCE_FIELD/LOCAL_VARIABLE/PARAMETER
      (constant    "#716994")   ; DEFAULT_CONSTANT/STATIC_FINAL_FIELD (violett)
      (label       "#cd92a1")   ; DEFAULT_LABEL (pink)
      (annotation  "#8e8e8e")   ; DEFAULT_METADATA (Annotationen, grau, fett)
      (attribute   "#d0d6b5")   ; DEFAULT_ATTRIBUTE (XML/HTML-Attribut)
      (predefined  "#f2c4b3")   ; DEFAULT_PREDEFINED_SYMBOL (this/self, salmon)
      (tag         "#e6958f")   ; HTML/XML_TAG_NAME (salmon-rot)
      (red         "#ff4262")   ; ERRORS
      (warn        "#d9c979")   ; WARNING error-stripe
      (warn-eff    "#eeecaa")   ; WARNING effect
      (green       "#508654")   ; ADDED_LINES / success
      (deleted     "#9c1a41")   ; DELETED_LINES
      (modified    "#266c78")   ; MODIFIED_LINES (teal)
      (blue        "#5d82ba")   ; CUSTOM_KEYWORD2 (blau)
      (cyan        "#0f859b")   ; KOTLIN_NAMED_ARGUMENT / TYPE_PARAMETER
      (link        "#2b85a8")   ; CSS.HASH (gut lesbares teal fuer Links)
      (brace-match "#73758a")   ; MATCHED_BRACE effect
      (ml-bg       "#0d2c37")   ; Mode-line-Hintergrund (aktiv)
      (diff-ins-bg "#031c1e")   ; DIFF_INSERTED bg
      (diff-del-bg "#2f091b")   ; DIFF_DELETED bg
      (diff-mod-bg "#1d242f")   ; DIFF_MODIFIED bg
      (diff-cnf-bg "#2f1e19")   ; DIFF_CONFLICT bg
      (search-bg   "#bfdeba"))  ; TEXT_SEARCH_RESULT bg

  (custom-theme-set-variables
   'custom-obsidian
   '(frame-background-mode (quote dark)))

  (custom-theme-set-faces
   'custom-obsidian

   ;; ---- Basis / Editor ----
   `(default        ((t (:foreground ,fg :background ,bg))))
   `(cursor         ((t (:background ,fg-bright))))
   `(region         ((t (:background ,bg-sel :foreground ,sel-fg :extend t))))
   `(secondary-selection ((t (:background ,bg-sel2 :extend t))))
   `(highlight      ((t (:background ,bg-sel))))
   `(hl-line        ((t (:background ,bg-line :extend t))))
   `(fringe         ((t (:background ,bg :foreground ,comment))))
   `(vertical-border ((t (:foreground ,border))))
   `(window-divider ((t (:foreground ,border))))
   `(window-divider-first-pixel ((t (:foreground ,border))))
   `(window-divider-last-pixel  ((t (:foreground ,border))))
   `(minibuffer-prompt ((t (:foreground ,keyword :weight bold))))
   `(shadow         ((t (:foreground ,comment))))
   `(link           ((t (:foreground ,link :underline t))))
   `(link-visited   ((t (:foreground ,constant :underline t))))
   `(match          ((t (:background ,bg-sel :foreground ,fg))))
   `(error          ((t (:foreground ,red :weight bold))))
   `(warning        ((t (:foreground ,warn :weight bold))))
   `(success        ((t (:foreground ,green :weight bold))))
   `(escape-glyph   ((t (:foreground ,predefined))))
   `(trailing-whitespace ((t (:background ,deleted))))
   `(tooltip        ((t (:background ,bg-line :foreground ,fg))))
   `(fill-column-indicator ((t (:foreground ,indent))))
   `(highlight-indent-guides-character-face ((t (:foreground ,indent))))

   ;; ---- Font Lock (Syntax) -- exakt nach Obsidian-Schema ----
   `(font-lock-comment-face           ((t (:foreground ,comment :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,comment :slant italic))))
   `(font-lock-doc-face               ((t (:foreground ,comment :slant italic))))
   `(font-lock-doc-markup-face        ((t (:foreground ,link))))
   `(font-lock-string-face            ((t (:foreground ,string))))
   `(font-lock-regexp-face            ((t (:foreground ,string))))
   `(font-lock-escape-face            ((t (:foreground ,string :weight bold))))
   `(font-lock-keyword-face           ((t (:foreground ,keyword))))
   `(font-lock-constant-face          ((t (:foreground ,constant :slant italic))))
   `(font-lock-builtin-face           ((t (:foreground ,predefined))))
   `(font-lock-function-name-face     ((t (:foreground ,func-decl))))
   `(font-lock-function-call-face     ((t (:foreground ,func-call))))
   `(font-lock-variable-name-face     ((t (:foreground ,field))))
   `(font-lock-variable-use-face      ((t (:foreground ,field))))
   `(font-lock-type-face              ((t (:foreground ,type :weight bold))))
   `(font-lock-preprocessor-face      ((t (:foreground ,annotation :weight bold))))
   `(font-lock-number-face            ((t (:foreground ,number))))
   `(font-lock-negation-char-face     ((t (:foreground ,red))))
   `(font-lock-warning-face           ((t (:foreground ,red :weight bold))))
   `(font-lock-operator-face          ((t (:foreground ,fg-bright))))
   `(font-lock-property-name-face     ((t (:foreground ,field))))
   `(font-lock-property-use-face      ((t (:foreground ,field))))
   `(font-lock-punctuation-face       ((t (:foreground ,fg-bright))))
   `(font-lock-delimiter-face         ((t (:foreground ,fg-bright))))
   `(font-lock-misc-punctuation-face  ((t (:foreground ,fg-bright))))
   `(font-lock-bracket-face           ((t (:foreground ,fg-bright))))
   ;; this/self & vordefinierte Symbole (salmon), Annotationen (grau), Labels (pink):
   `(tree-sitter-hl-face:variable.builtin ((t (:foreground ,predefined))))
   `(tree-sitter-hl-face:attribute        ((t (:foreground ,annotation :weight bold))))
   `(tree-sitter-hl-face:label            ((t (:foreground ,label))))
   `(tree-sitter-hl-face:type.builtin     ((t (:foreground ,type :weight bold))))
   `(tree-sitter-hl-face:constant.builtin ((t (:foreground ,constant :slant italic))))

   ;; ---- Zeilennummern ----
   `(line-number              ((t (:inherit default :foreground ,linenr))))
   `(line-number-current-line ((t (:inherit default :foreground ,linenr-cur :weight bold))))

   ;; ---- Mode line / Statusline ----
   `(mode-line          ((t (:background ,ml-bg :foreground ,fg :box nil))))
   `(mode-line-active   ((t (:background ,ml-bg :foreground ,fg :box nil))))
   `(mode-line-inactive ((t (:background ,bg-line :foreground ,comment :box nil))))
   `(mode-line-buffer-id ((t (:foreground ,keyword :weight bold))))
   `(mode-line-emphasis  ((t (:foreground ,keyword :weight bold))))
   `(mode-line-highlight ((t (:background ,bg-sel))))
   `(doom-modeline-buffer-file        ((t (:foreground ,fg :weight bold))))
   `(doom-modeline-buffer-modified    ((t (:foreground ,red :weight bold))))
   `(doom-modeline-buffer-path        ((t (:foreground ,field))))
   `(doom-modeline-project-dir        ((t (:foreground ,keyword :weight bold))))
   `(doom-modeline-info               ((t (:foreground ,green))))
   `(doom-modeline-warning            ((t (:foreground ,warn))))
   `(doom-modeline-urgent             ((t (:foreground ,red))))
   `(doom-modeline-bar                ((t (:background ,modified))))
   `(doom-modeline-bar-inactive       ((t (:background ,bg-line))))
   `(doom-modeline-evil-normal-state  ((t (:foreground ,func-call))))
   `(doom-modeline-evil-insert-state  ((t (:foreground ,green :weight bold))))
   `(doom-modeline-evil-visual-state  ((t (:foreground ,keyword :weight bold))))
   `(doom-modeline-evil-replace-state ((t (:foreground ,red :weight bold))))

   ;; ---- Suche ----
   `(isearch        ((t (:background ,search-bg :foreground ,bg :weight bold))))
   `(isearch-fail   ((t (:background ,red :foreground ,bg))))
   `(lazy-highlight ((t (:background ,bg-sel2 :foreground ,fg))))
   `(evil-ex-search ((t (:background ,search-bg :foreground ,bg))))

   ;; ---- Klammern ----
   `(show-paren-match    ((t (:background ,bg-sel2 :foreground ,keyword :weight bold))))
   `(show-paren-mismatch ((t (:background ,red :foreground ,bg :weight bold))))
   `(rainbow-delimiters-depth-1-face ((t (:foreground ,keyword))))
   `(rainbow-delimiters-depth-2-face ((t (:foreground ,func-call))))
   `(rainbow-delimiters-depth-3-face ((t (:foreground ,string))))
   `(rainbow-delimiters-depth-4-face ((t (:foreground ,label))))
   `(rainbow-delimiters-depth-5-face ((t (:foreground ,cyan))))
   `(rainbow-delimiters-depth-6-face ((t (:foreground ,constant))))
   `(rainbow-delimiters-depth-7-face ((t (:foreground ,predefined))))
   `(rainbow-delimiters-unmatched-face ((t (:foreground ,red :weight bold))))

   ;; ---- Vertico / Corfu / Marginalia / Orderless ----
   `(vertico-current      ((t (:background ,bg-sel :extend t))))
   `(corfu-default        ((t (:background ,bg-line :foreground ,fg))))
   `(corfu-current        ((t (:background ,bg-sel :foreground ,fg))))
   `(corfu-bar            ((t (:background ,field))))
   `(corfu-border         ((t (:background ,border))))
   `(marginalia-key       ((t (:foreground ,keyword))))
   `(marginalia-documentation ((t (:foreground ,comment))))
   `(orderless-match-face-0 ((t (:foreground ,keyword :weight bold))))
   `(orderless-match-face-1 ((t (:foreground ,func-call :weight bold))))
   `(orderless-match-face-2 ((t (:foreground ,string :weight bold))))
   `(orderless-match-face-3 ((t (:foreground ,label :weight bold))))
   `(completions-common-part ((t (:foreground ,keyword :weight bold))))
   `(completions-annotations ((t (:foreground ,comment))))

   ;; ---- company ----
   `(company-tooltip            ((t (:background ,bg-line :foreground ,fg))))
   `(company-tooltip-selection  ((t (:background ,bg-sel :foreground ,fg))))
   `(company-tooltip-common     ((t (:foreground ,keyword :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,comment))))
   `(company-scrollbar-bg       ((t (:background ,bg))))
   `(company-scrollbar-fg       ((t (:background ,field))))
   `(company-preview            ((t (:foreground ,comment))))
   `(company-preview-common     ((t (:foreground ,keyword))))

   ;; ---- Diagnostics (flycheck / flymake / lsp) ----
   `(flycheck-error   ((t (:underline (:style wave :color ,red)))))
   `(flycheck-warning ((t (:underline (:style wave :color ,warn)))))
   `(flycheck-info    ((t (:underline (:style wave :color ,modified)))))
   `(flymake-error    ((t (:underline (:style wave :color ,red)))))
   `(flymake-warning  ((t (:underline (:style wave :color ,warn)))))
   `(flymake-note     ((t (:underline (:style wave :color ,modified)))))
   `(lsp-ui-sideline-code-action ((t (:foreground ,keyword))))
   `(lsp-face-highlight-textual  ((t (:background ,bg-sel))))
   `(lsp-face-highlight-read     ((t (:background ,bg-sel))))
   `(lsp-face-highlight-write    ((t (:background ,bg-sel2))))
   `(lsp-headerline-breadcrumb-path-face ((t (:foreground ,comment))))
   `(lsp-headerline-breadcrumb-symbols-face ((t (:foreground ,fg))))

   ;; ---- Diff / ediff / Magit ----
   `(diff-added     ((t (:foreground ,green :background ,diff-ins-bg :extend t))))
   `(diff-removed   ((t (:foreground ,deleted :background ,diff-del-bg :extend t))))
   `(diff-changed   ((t (:foreground ,modified :background ,diff-mod-bg :extend t))))
   `(diff-header    ((t (:foreground ,func-call :weight bold))))
   `(diff-file-header ((t (:foreground ,fg :weight bold))))
   `(diff-hunk-header ((t (:foreground ,comment :background ,bg-line))))
   `(ediff-current-diff-A ((t (:background ,bg :extend t))))
   `(ediff-current-diff-B ((t (:background ,bg :extend t))))
   `(ediff-current-diff-C ((t (:background ,bg :extend t))))
   `(ediff-fine-diff-A ((t (:background ,diff-del-bg))))
   `(ediff-fine-diff-B ((t (:background ,diff-ins-bg))))
   `(ediff-fine-diff-C ((t (:background ,diff-mod-bg))))
   `(ediff-even-diff-A ((t (:background ,bg :extend t))))
   `(ediff-even-diff-B ((t (:background ,bg :extend t))))
   `(ediff-even-diff-C ((t (:background ,bg :extend t))))
   `(ediff-odd-diff-A  ((t (:background ,bg :extend t))))
   `(ediff-odd-diff-B  ((t (:background ,bg :extend t))))
   `(ediff-odd-diff-C  ((t (:background ,bg :extend t))))
   `(magit-section-heading     ((t (:foreground ,keyword :weight bold))))
   `(magit-section-highlight   ((t (:background ,bg-line :extend t))))
   `(magit-branch-local        ((t (:foreground ,func-call :weight bold))))
   `(magit-branch-remote       ((t (:foreground ,green :weight bold))))
   `(magit-tag                 ((t (:foreground ,keyword))))
   `(magit-hash                ((t (:foreground ,comment))))
   `(magit-log-author          ((t (:foreground ,label))))
   `(magit-log-date            ((t (:foreground ,comment))))
   `(magit-diff-added          ((t (:foreground ,green :background ,diff-ins-bg :extend t))))
   `(magit-diff-added-highlight ((t (:foreground ,green :background ,diff-mod-bg :extend t))))
   `(magit-diff-removed        ((t (:foreground ,deleted :background ,diff-del-bg :extend t))))
   `(magit-diff-removed-highlight ((t (:foreground ,deleted :background ,diff-del-bg :extend t))))
   `(magit-diff-context        ((t (:foreground ,comment :extend t))))
   `(magit-diff-context-highlight ((t (:foreground ,fg :background ,bg-line :extend t))))
   `(magit-diff-hunk-heading   ((t (:foreground ,comment :background ,bg-line :extend t))))
   `(magit-diff-hunk-heading-highlight ((t (:foreground ,fg :background ,border :extend t))))

   ;; ---- diff-hl / git-gutter (Fringe-Indikatoren) ----
   `(diff-hl-insert ((t (:foreground ,green :background ,green))))
   `(diff-hl-delete ((t (:foreground ,deleted :background ,deleted))))
   `(diff-hl-change ((t (:foreground ,modified :background ,modified))))
   `(git-gutter:added    ((t (:foreground ,green))))
   `(git-gutter:deleted  ((t (:foreground ,deleted))))
   `(git-gutter:modified ((t (:foreground ,modified))))

   ;; ---- Org Mode ----
   `(org-level-1     ((t (:foreground ,keyword :weight bold :height 1.15))))
   `(org-level-2     ((t (:foreground ,func-call :weight bold :height 1.1))))
   `(org-level-3     ((t (:foreground ,string :weight bold))))
   `(org-level-4     ((t (:foreground ,label :weight bold))))
   `(org-level-5     ((t (:foreground ,type))))
   `(org-level-6     ((t (:foreground ,cyan))))
   `(org-level-7     ((t (:foreground ,constant))))
   `(org-level-8     ((t (:foreground ,predefined))))
   `(org-document-title ((t (:foreground ,keyword :weight bold :height 1.3))))
   `(org-todo        ((t (:foreground ,red :weight bold))))
   `(org-done        ((t (:foreground ,green :weight bold))))
   `(org-headline-done ((t (:foreground ,comment))))
   `(org-link        ((t (:foreground ,link :underline t))))
   `(org-code        ((t (:foreground ,predefined))))
   `(org-verbatim    ((t (:foreground ,string))))
   `(org-block       ((t (:background ,bg-line :extend t))))
   `(org-block-begin-line ((t (:foreground ,comment :background ,bg-line :extend t))))
   `(org-block-end-line   ((t (:foreground ,comment :background ,bg-line :extend t))))
   `(org-table       ((t (:foreground ,func-call))))
   `(org-date        ((t (:foreground ,cyan :underline t))))
   `(org-special-keyword ((t (:foreground ,comment))))
   `(org-drawer      ((t (:foreground ,comment))))
   `(org-agenda-structure ((t (:foreground ,func-call :weight bold))))
   `(org-agenda-date  ((t (:foreground ,func-call))))
   `(org-agenda-date-today ((t (:foreground ,keyword :weight bold))))
   `(org-scheduled    ((t (:foreground ,green))))
   `(org-scheduled-today ((t (:foreground ,fg))))
   `(org-warning      ((t (:foreground ,red :weight bold))))

   ;; ---- Dired / Treemacs ----
   `(dired-directory ((t (:foreground ,func-call :weight bold))))
   `(dired-symlink   ((t (:foreground ,cyan))))
   `(dired-ignored   ((t (:foreground ,comment))))
   `(treemacs-root-face ((t (:foreground ,keyword :weight bold :height 1.1))))
   `(treemacs-directory-face ((t (:foreground ,func-call))))
   `(treemacs-file-face ((t (:foreground ,fg))))
   `(treemacs-git-modified-face ((t (:foreground ,modified))))
   `(treemacs-git-added-face ((t (:foreground ,green))))
   `(treemacs-git-untracked-face ((t (:foreground ,comment))))

   ;; ---- Tab bar / Tab line ----
   `(tab-bar          ((t (:background ,bg-line :foreground ,comment))))
   `(tab-bar-tab      ((t (:background ,bg :foreground ,keyword :weight bold))))
   `(tab-bar-tab-inactive ((t (:background ,bg-line :foreground ,comment))))
   `(tab-line         ((t (:background ,bg-line :foreground ,comment))))

   ;; ---- which-key ----
   `(which-key-key-face ((t (:foreground ,keyword :weight bold))))
   `(which-key-command-description-face ((t (:foreground ,fg))))
   `(which-key-group-description-face ((t (:foreground ,func-call))))
   `(which-key-separator-face ((t (:foreground ,comment))))

   ;; ---- ANSI / term Farben ----
   `(term-color-black   ((t (:foreground ,bg-line :background ,bg-line))))
   `(term-color-red     ((t (:foreground ,red :background ,red))))
   `(term-color-green   ((t (:foreground ,string :background ,string))))
   `(term-color-yellow  ((t (:foreground ,keyword :background ,keyword))))
   `(term-color-blue    ((t (:foreground ,func-call :background ,func-call))))
   `(term-color-magenta ((t (:foreground ,label :background ,label))))
   `(term-color-cyan    ((t (:foreground ,cyan :background ,cyan))))
   `(term-color-white   ((t (:foreground ,fg :background ,fg))))

   ;; ---- Doom Dashboard / Startfenster ----
   `(doom-dashboard-banner ((t (:foreground ,func-call))))
   `(doom-dashboard-menu-title ((t (:foreground ,keyword :weight bold))))
   `(doom-dashboard-menu-desc  ((t (:foreground ,label))))
   `(doom-dashboard-footer     ((t (:foreground ,comment))))
   `(doom-dashboard-loaded     ((t (:foreground ,comment)))))

  (custom-theme-set-variables
   'custom-obsidian
   `(ansi-color-names-vector
     [,bg-line ,red ,string ,keyword ,func-call ,label ,cyan ,fg])))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'custom-obsidian)

;; Local Variables:
;; no-byte-compile: t
;; indent-tabs-mode: nil
;; eval: (when (fboundp 'rainbow-mode) (rainbow-mode +1))
;; End:

;;; custom-obsidian-theme.el ends here
