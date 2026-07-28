;;; +java.el -*- lexical-binding: t; -*-
;;
;; Java/Spring-IDE-Erweiterungen fuer Doom (IntelliJ-Paritaet).
;; Geladen via (load! "+java") aus config.el. Dokumentation: siehe docs/.
;;
;; Enthaelt:
;;   - JDT/LSP-Kern (Java 21 Runtime, Projekt-Java 17, Performance)
;;   - Formatierung nach IntelliJ-Schema (gcIntellijCodeStyle)
;;   - Maven-Menue (Transient)
;;   - Run/Debug-Picker aus .idea/runConfigurations
;;   - Interface<->Impl-Navigation, Override/Implement, Code-Generierung
;;   - Postgres-DB-Viewer (pgmacs)
;;   - Java-Profiler (async-profiler -> flamegraph)
;;   - alle zugehoerigen Keybindings (Java-Localleader SPC m)

(require 'transient)   ; fuer das Maven-Menue (transient-define-prefix)
(require 'dom)         ; fuer das Parsen der IntelliJ-Run-Config-XMLs


;;; --------------------------------------------------------------------------
;;; 1. JDT/LSP-Kern
;;; --------------------------------------------------------------------------

(after! lsp-java
  ;; JDT.LS mit Java 21 starten, Projekt aber gegen Java 17 kompilieren:
  (setq lsp-java-java-path
        "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home/bin/java"
        lsp-java-configuration-runtimes
        '[(:name "JavaSE-17" :path "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home" :default t)
          (:name "JavaSE-21" :path "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home")]
        ;; Genug Heap fuer das grosse Reactor-Projekt:
        lsp-java-vmargs '("-XX:+UseParallelGC" "-Xmx4G" "-Xms100m")
        lsp-java-maven-download-sources t              ; Quellen mitladen (Go-to-Source)
        lsp-java-references-code-lens-enabled t         ; "N references" ueber Methoden
        lsp-java-implementations-code-lens-enabled t    ; "N implementations" ueber Interfaces
        lsp-java-save-actions-organize-imports t))      ; Imports beim Speichern ordnen

;; --- Generierte Sourcen (swagger/openapi etc.) als Source-Root in .classpath ---
;; JDT.LS/m2e registriert von Code-Generatoren (z.B. swagger-codegen) erzeugte Ordner
;; NICHT als Source-Root: das Plugin hat kein m2e-Lifecycle-Mapping, und generisches
;; `defaultMojoExecutionAction' = "execute" laesst die Mojo zwar laufen, traegt den per
;; `addCompileSourceRoot' hinzugefuegten Ordner aber NICHT in den Eclipse-Classpath ein
;; (empirisch verifiziert). Folge: generierte Typen wie `SitzungenApi' sind "cannot be
;; resolved" und nicht anspringbar. IntelliJ markiert `target/generated-sources/**'
;; automatisch -- wir tun das hier rein lokal in der (nicht versionierten) .classpath.
;; Der Source-Root wird generisch ueber das package der generierten .java abgeleitet
;; (also nicht auf swagger festgenagelt). Ausfuehren: `SPC m G' (oder automatisch nach
;; `SPC m u' / "Update Project Configuration", das die .classpath neu erzeugt).
(defun +java--file-package (file)
  "package-Deklaration aus FILE lesen (oder nil)."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents file nil 0 4000)
      (goto-char (point-min))
      (when (re-search-forward "^[ \t]*package[ \t]+\\([[:alnum:]_.]+\\)[ \t]*;" nil t)
        (match-string 1)))))

(defun +java--source-root-of (file)
  "Source-Root von FILE anhand seines package ableiten (ohne End-Slash) oder nil."
  (when-let* ((pkg  (+java--file-package file))
              (tail (concat (replace-regexp-in-string "\\." "/" pkg) "/"
                            (file-name-nondirectory file))))
    (when (string-suffix-p tail file)
      (directory-file-name (substring file 0 (- (length file) (length tail)))))))

(defun +java--generated-source-roots (module-dir)
  "Source-Root-Verzeichnisse unter MODULE-DIR/target/generated-sources mit .java."
  (require 'cl-lib)
  (let ((gen (expand-file-name "target/generated-sources" module-dir))
        roots)
    (when (file-directory-p gen)
      (dolist (f (directory-files-recursively gen "\\.java\\'"))
        (when-let ((r (+java--source-root-of f)))
          (cl-pushnew r roots :test #'string=))))
    roots))

(defun +java--classpath-add-src (module-dir rel)
  "REL als <classpathentry kind=src> in MODULE-DIR/.classpath eintragen, falls fehlt.
Gibt t bei Aenderung zurueck."
  (let ((cp (expand-file-name ".classpath" module-dir)))
    (when (file-exists-p cp)
      (with-temp-buffer
        (insert-file-contents cp)
        (goto-char (point-min))
        (unless (search-forward (format "path=\"%s\"" rel) nil t)
          (goto-char (point-min))
          (when (search-forward "</classpath>" nil t)
            (goto-char (match-beginning 0))
            (insert (format (concat "\t<classpathentry kind=\"src\" path=\"%s\">\n"
                                    "\t\t<attributes>\n"
                                    "\t\t\t<attribute name=\"optional\" value=\"true\"/>\n"
                                    "\t\t</attributes>\n"
                                    "\t</classpathentry>\n")
                            rel))
            (write-region (point-min) (point-max) cp nil 'silent)
            t))))))

(defun +java--reactor-module-dirs (root)
  "ROOT + direkte Unterordner, die eine .classpath besitzen."
  (cons (directory-file-name root)
        (seq-filter (lambda (d) (file-exists-p (expand-file-name ".classpath" d)))
                    (seq-filter #'file-directory-p
                                (ignore-errors (directory-files root t "\\`[^.]"))))))

(defun +java--jdtls-workspaces ()
  "Alle aktiven JDT.LS-Workspaces der Session."
  (ignore-errors (lsp-find-workspace 'jdtls nil)))

(defun +java/ensure-generated-source-roots (&optional no-restart)
  "Generierte Source-Roots (z.B. swagger) in die .classpath der Reactor-Module
eintragen, damit JDT.LS generierte Typen aufloest. Bei Aenderung wird der JDT.LS-
Workspace neu gestartet (noetig, damit die .classpath neu gelesen wird); mit Praefix
(\\[universal-argument]) OHNE Neustart."
  (interactive "P")
  (let* ((root    (or (ignore-errors (+idea--project-root))
                      (projectile-project-root)
                      default-directory))
         (changed nil))
    (dolist (mod (+java--reactor-module-dirs root))
      (dolist (sr (+java--generated-source-roots mod))
        (let ((rel (file-relative-name sr mod)))
          (when (+java--classpath-add-src mod rel)
            (push (file-relative-name sr root) changed)))))
    (cond
     ((null changed)
      (message "Generated-Source-Roots: nichts zu tun (alles vorhanden)"))
     (no-restart
      (message "Generated-Source-Roots ergaenzt: %s -- Workspace neu starten (SPC m L)"
               (string-join changed ", ")))
     (t
      (message "Generated-Source-Roots ergaenzt: %s -- starte JDT.LS neu ..."
               (string-join changed ", "))
      (dolist (w (+java--jdtls-workspaces)) (ignore-errors (lsp-workspace-restart w)))))))

;; Nach echtem "Update Project Configuration" (regeneriert .classpath -> unser Eintrag
;; ist weg) verzoegert nachziehen (der Update ist asynchron). Restart erfolgt nur, wenn
;; wirklich etwas ergaenzt wurde.
(with-eval-after-load 'lsp-java
  (advice-add 'lsp-java-update-project-configuration :after
              (lambda (&rest _)
                (run-at-time 12 nil #'+java/ensure-generated-source-roots))))

(after! lsp-mode
  ;; ---- Performance (grosses Reactor-Projekt; "wird beim Nutzen immer langsamer") ----
  ;; Hintergrund: Die Verlangsamung kommt v.a. von (a) staendigen LSP-Neuberechnungen
  ;; bei jeder Cursorbewegung/jedem Scrollen und (b) zu vielen Datei-Watchern.
  (setq lsp-idle-delay 1.0                       ; seltener neu rechnen (Diagnostics/Lens/Doc)
        lsp-log-io nil                           ; KEIN I/O-Logging (riesige Buffer = langsam)
        lsp-enable-symbol-highlighting nil       ; nicht bei jeder Cursorbewegung neu highlighten
        lsp-enable-on-type-formatting nil        ; nicht waehrend des Tippens umformatieren
        lsp-enable-text-document-color nil       ; kein Farb-Overlay fuer Hex/CSS-Farben
        lsp-headerline-breadcrumb-enable nil     ; Breadcrumb-Leiste spart Redraw-Aufwand
        lsp-modeline-code-actions-enable t       ; Lightbulb in der Modeline: zeigt, wenn Quick-Fixes/Code-Actions verfuegbar sind (wie IntelliJ). Ausfuehren via SPC c a
        lsp-modeline-workspace-status-enable nil
        ;; CodeLens (Referenz-/Implementierungs-Zaehler ueber dem Code) AUS: es feuert
        ;; laufend `textDocument/codeLens'+`codeLens/resolve' fuer jede sichtbare Methode
        ;; -- bei 8 offenen Maven-Projekten spuerbare Dauerlast, die mit Go-to-Definition
        ;; um den Server konkurriert. Bei Bedarf pro Buffer wieder an: SPC m l.
        lsp-lens-enable nil
        ;; WICHTIG: t = JDT.LS-Server bleibt am Leben, auch wenn KEIN Java-Buffer mehr
        ;; offen/sichtbar ist. Mit nil fuhr der Server beim Wegspringen (z.B. in den
        ;; Docker-Container-Buffer, anderes Projekt) herunter, sobald der letzte
        ;; Java-Buffer gekillt/verlassen wurde -> beim Zurueckkommen kompletter
        ;; Maven-Reactor-Reimport (Minuten), in der Zeit KEINE Vorschlaege. Wie IntelliJ
        ;; das Projektmodell dauerhaft haelt -> t. Bewusst beenden: M-x lsp-workspace-shutdown.
        lsp-keep-workspace-alive t
        lsp-signature-render-documentation nil   ; Signatur ohne langes Doc-Rendering
        ;; Watcher: 100000 hiess "ueberwache fast alles" -> dauerhafte CPU-Last bei grossen
        ;; Reactors. Schwelle senken + mehr Build-/Tool-Ordner ignorieren:
        lsp-file-watch-threshold 8000)
  (dolist (re '("[/\\\\]target\\'" "[/\\\\]\\.idea\\'" "[/\\\\]node_modules\\'"
                "[/\\\\]\\.git\\'" "[/\\\\]\\.settings\\'" "[/\\\\]bin\\'"
                "[/\\\\]build\\'" "[/\\\\]out\\'" "[/\\\\]dist\\'" "[/\\\\]logs\\'"))
    (add-to-list 'lsp-file-watch-ignored-directories re)))

(after! lsp-ui
  ;; Sideline bleibt AN fuer Diagnostics (zeigt z.B. "unused import"-Warnungen inline,
  ;; siehe Item Git-Diff), aber die teuren Teile (Hover/Code-Actions) aus + nur bei
  ;; Zeilenwechsel statt bei jeder Cursorbewegung aktualisieren -> spuerbar fluessiger.
  (setq lsp-ui-doc-delay 0.5
        lsp-ui-sideline-enable t
        lsp-ui-sideline-show-diagnostics t
        lsp-ui-sideline-show-hover nil
        lsp-ui-sideline-show-code-actions nil
        lsp-ui-sideline-update-mode 'line
        lsp-ui-sideline-delay 0.3))

(setq read-process-output-max (* 4 1024 1024))          ; groessere LSP-Antworten zulassen

;; WICHTIG (Auto-Complete-Fix): lsp-java sendet `java.format.tabSize' aus
;; `c-basic-offset'. Wird die Einstellung in einem Kontext berechnet, in dem cc-mode den
;; Wert nie gesetzt hat (z.B. java-ts-mode oder nicht-cc-Buffer), ist `c-basic-offset'
;; noch der Symbol-Default `set-from-style'. Das ist kein JSON-Wert -> der Versand der
;; Server-Konfiguration scheitert ("Wrong type argument: json-value-p, set-from-style"),
;; der Buffer wird nicht sauber registriert und JDT.LS meldet spaeter "does not support
;; method textDocument/completion". Default auf eine Zahl setzen behebt die Wurzel:
(setq-default c-basic-offset 2)

;; java-ts-mode (aktiv durch `(java +tree-sitter)') nutzt zum Einruecken -- und als
;; `tabSize' der LSP-Format-Anfrage (SPC c f) -- `java-ts-mode-indent-offset' (Default
;; 4). Unser Projekt/IntelliJ-Profil ist 2. Ohne Override schickt die Format-Anfrage
;; tabSize=4 und ueberschreibt damit das 2er-Eclipse-Profil -> Ausgabe mit 4er-Einrueckung
;; (der Eclipse-Formatter selbst ist korrekt 2). Darum global auf 2. Eine projekt-eigene
;; .editorconfig darf das weiterhin pro Buffer ueberschreiben.
(with-eval-after-load 'java-ts-mode
  (setq-default java-ts-mode-indent-offset 2))

;; WICHTIG: Doom haengt den LSP-Autostart (lsp!) nur an java-mode-local-vars-hook.
;; Mit (java +tree-sitter) laufen .java-Dateien aber in java-ts-mode -> JDT.LS wuerde
;; dort NICHT automatisch starten (genau das verursacht "resolveClasspath failed" /
;; "does not support workspace/executeCommand", weil gar kein Java-Server laeuft).
(add-hook 'java-ts-mode-local-vars-hook #'lsp! 'append)

;; --------------------------------------------------------------------------
;; Sicherheitsnetz: lsp beim Zurueckwechseln in einen Java/Kotlin-Buffer nachstarten
;; --------------------------------------------------------------------------
;; `lsp!' ist DEFERRED (`lsp-deferred'): lsp startet erst, wenn der Buffer sichtbar wird.
;; Feuert dieser deferred-Trigger einmal ins Leere (z.B. weil der JDT.LS-Server gerade
;; neu startete / importierte), wird er NICHT wiederholt -> der Buffer bleibt dauerhaft
;; OHNE lsp-mode: kein `lsp-completion-at-point' im capf, kein `lsp-completion-mode' ->
;; GAR KEINE Vorschlaege, obwohl der Server laeuft. Symptom: "springt in Docker-Buffer
;; und zurueck, dann keine Vorschlaege mehr".
;; Fix: bei jedem Buffer-Wechsel pruefen -- ist es ein Java/Kotlin-DATEI-Buffer ohne
;; lsp-mode, lsp (deferred) erneut anstossen. Dank `lsp-keep-workspace-alive t' haengt
;; sich der Buffer sofort an den LAUFENDEN Server (kein Reimport).
(defun +java/ensure-lsp-maybe-h ()
  "In Java/Kotlin-Datei-Buffern lsp (erneut) starten, falls `lsp-mode' aus ist."
  (when (and buffer-file-name
             (derived-mode-p 'java-mode 'java-ts-mode 'kotlin-mode 'kotlin-ts-mode)
             (not (bound-and-true-p lsp-mode))
             (fboundp 'lsp-deferred))
    (lsp-deferred)))
(add-hook 'doom-switch-buffer-hook #'+java/ensure-lsp-maybe-h)

;;;###autoload
(defun +java/lsp-reconnect ()
  "lsp im aktuellen Buffer (neu) starten -- manuelle Reparatur, falls Vorschlaege fehlen.
Startet lsp, wenn es aus ist; laeuft es bereits, wird die Workspace-Verbindung neu
aufgebaut (`lsp-workspace-restart'). Dank `lsp-keep-workspace-alive t' i.d.R. ohne
kompletten Reimport."
  (interactive)
  (if (bound-and-true-p lsp-mode)
      (call-interactively #'lsp-workspace-restart)
    (lsp)))

;;;###autoload
(defun +java/lsp-prune-to-current-project ()
  "Alle JDT.LS-Workspace-Ordner ENTFERNEN ausser dem aktuellen Projekt.
Behebt die Verlangsamung/`g d'-Haenger, wenn sich mit der Zeit viele FREMDE Maven-
Projekte im selben JDT.LS angesammelt haben (jedes = eigener Reactor -> staendige
Re-Imports + viele Datei-Watcher, die den synchronen Definition-Request blockieren).
Danach ggf. `SPC m L' (reconnect)."
  (interactive)
  (let* ((keep    (directory-file-name (or (doom-project-root) default-directory)))
         (folders (ignore-errors (lsp-session-folders (lsp-session))))
         (remove  (seq-remove (lambda (f) (string= (directory-file-name f) keep)) folders)))
    (cond
     ((null folders) (user-error "Keine aktive lsp-Session"))
     ((null remove)  (message "Nur das aktuelle Projekt (%s) im Workspace -- nichts zu tun."
                              (file-name-nondirectory keep)))
     (t (when (yes-or-no-p (format "%d Fremd-Projekt(e) aus dem JDT.LS-Workspace entfernen (behalten: %s)? "
                                   (length remove) (file-name-nondirectory keep)))
          (dolist (f remove) (ignore-errors (lsp-workspace-folders-remove f)))
          (message "Entfernt: %d Projekt(e). Behalten: %s. Bei fehlenden Vorschlaegen: SPC m L."
                   (length remove) (file-name-nondirectory keep)))))))

;; Spring-Boot-LS (STS4 / "boot-ls") DEAKTIVIEREN: Dieses Projekt ist klassisches
;; Spring + Wicket (kein Spring Boot). Der boot-ls startet einen eigenen TCP-JVM, der
;; hier fehlschlaegt ("Failed to create connection to boot-ls on port ...") -- das bringt
;; nur Fehler-Spam und Verzoegerung beim Start. Die Java-Vervollstaendigung liefert
;; ohnehin JDT.LS allein.
(setq lsp-java-boot-enabled nil)                         ; boot-ls gar nicht erst starten
(after! lsp-mode
  (add-to-list 'lsp-disabled-clients 'boot-ls))          ; zur Sicherheit komplett deaktivieren

;; SonarLint-Inspections (IntelliJ-SonarLint-Aequivalent):
(use-package! lsp-sonarlint :after lsp-mode)

;; Mehrfachauswahl fuer Override/Implement, Getter/Setter, toString, equals/hashCode etc.
;; (SPC m g o usw.). Problem mit vertico: lsp-javas Original-Fallback togglet pro RET nur
;; eine Methode und fragt endlos weiter -- ein "Fertig" gibt es nur ueber das Abschicken
;; einer LEEREN Eingabe, was mit vertico kaum bedienbar ist (RET waehlt immer den Kandidaten).
;; Folge: Auswahl bestaetigen "passiert nix" / Abbruch via C-g verwirft alles.
;; Loesung: Funktion ueberschreiben und einen expliziten "[Fertig]"-Eintrag anbieten.
;; Bedienung: Eintraege mit RET an-/abwaehlen (Haken ✓), dann "[Fertig]" waehlen -> uebernehmen.
;; (helm/ivy behalten ihr eigenes, funktionierendes Verhalten.)
(after! lsp-java
  (defun lsp-java--completing-read-multiple (message items initial-selection)
    (cond
     ((functionp 'helm)
      (require 'helm-source)
      (helm :sources (helm-make-source
                      message 'helm-source-sync :candidates items
                      :action '(("Identity" lambda (_)
                                 (setq lsp-java--helm-result (helm-marked-candidates)))))
            :buffer "*lsp-java select*" :prompt message)
      lsp-java--helm-result)
     ((functionp 'ivy-read)
      (let (result)
        (ivy-read message (mapcar #'car items)
                  :action (lambda (c) (setq result (list (cdr (assoc c items)))))
                  :multi-action (lambda (cands)
                                  (setq result (mapcar (lambda (c) (cdr (assoc c items))) cands))))
        result))
     (t
      ;; vertico/completing-read: Toggle-Loop mit explizitem "[Fertig]"-Eintrag.
      (let ((deps initial-selection)
            (done "  ✔ [Fertig – Auswahl übernehmen]")
            (continue t))
        (while continue
          (let* ((coll (cons (cons done 'lsp-java--done)
                             (mapcar (-lambda ((name . id))
                                       (cons (if (-contains? deps id) (concat name " ✓") name)
                                             id))
                                     items)))
                 (sel (completing-read
                       (format "%s (ausgewaehlt %s): " message (length deps))
                       (lambda (string pred action)
                         (if (eq action 'metadata)
                             '(metadata (display-sort-function . identity))
                           (complete-with-action action coll string pred)))
                       nil t))
                 (choice (cdr (assoc sel coll))))
            (cond
             ((eq choice 'lsp-java--done) (setq continue nil))
             ((-contains? deps choice)    (setq deps (remove choice deps)))
             (t                           (cl-pushnew choice deps)))))
        deps)))))

;; Override speziell: EINZELauswahl statt Mehrfachauswahl. Eine Methode waehlen ->
;; sie wird sofort overridden (kein An-/Abwaehlen, kein "Fertig"). Ueberschreibt nur
;; den Override-Prompt; Getter/Setter/toString/equals nutzen weiter die Mehrfachauswahl.
(after! lsp-java
  (defun lsp-java--override-methods-prompt (action)
    (lsp-java-with-jdtls
      (let* ((context (lsp-seq-first (lsp:command-arguments? action)))
             (result (lsp-request "java/listOverridableMethods" context))
             (methods-data (-map (-lambda ((field &as &java:OverridableMethod
                                                  :name :parameters :declaring-class class))
                                   (cons (format "%s(%s) class: %s" name (s-join ", " parameters) class)
                                         field))
                                 (lsp:java-list-overridable-methods-methods result)))
             (choice (completing-read "Methode overriden: " (mapcar #'car methods-data) nil t))
             (field  (cdr (assoc choice methods-data))))
        (lsp-java--apply-document-changes
         (lsp-request "java/addOverridableMethods"
                      (list :overridableMethods (vector field)   ; genau die eine gewaehlte Methode
                            :context context)))))))


;;; --------------------------------------------------------------------------
;;; 2. Formatierung nach IntelliJ-Schema (gcIntellijCodeStyle)
;;; --------------------------------------------------------------------------

(after! lsp-java
  ;; Eclipse-Formatter-Profil (aus IntelliJ gcIntellijCodeStyle abgeleitet):
  (setq lsp-java-format-settings-url
        (expand-file-name "formatter/gc-eclipse-format.xml" doom-user-dir)
        lsp-java-format-settings-profile "gcIntellijCodeStyle"
        ;; Import-Reihenfolge analog IntelliJ-Layout (java, javax, org, com, Rest):
        lsp-java-import-order ["" "java" "javax" "org" "com"]))

;; (Frueherer lsp-response-timeout-Override entfernt: 10s reichen -- das
;;  Problem war ein blockierter macOS-NS-Event-Loop, nicht JDT. Siehe docs.)
;; Java/Kotlin NICHT ueber apheleia formatieren (sonst Google-Style-Konflikt),
;; sondern ueber den JDT-Formatter mit deinem Profil:
(after! apheleia
  (dolist (m '(java-mode java-ts-mode kotlin-mode kotlin-ts-mode))
    (setf (alist-get m apheleia-mode-alist nil 'remove) nil)))

;; Formatieren nach dem IntelliJ-Profil, gebunden auf SPC c f (siehe map! unten).
;; Hinweis: Der Eclipse-JDT-Formatter kann IntelliJs Code-Style-XML NICHT direkt
;; lesen. Deshalb liegt das Schema als Eclipse-Profil unter
;; `formatter/gc-eclipse-format.xml' (aus `formatter/gcIntellijCodeStyle.xml'
;; abgeleitet) und wird oben via `lsp-java-format-settings-url' aktiviert.
;;;###autoload
(defun +format/intellij ()
  "Nach dem IntelliJ-Schema (gcIntellijCodeStyle) formatieren.
Region falls aktiv, sonst der ganze Buffer. Fuer Java/Kotlin laeuft das ueber den
JDT-Formatter mit dem in `lsp-java-format-settings-url' hinterlegten Eclipse-Profil
(aus deinem IntelliJ-Schema abgeleitet). In Nicht-LSP-Buffern faellt der Befehl auf
Dooms `+format/region-or-buffer' (apheleia) zurueck, sodass SPC c f ueberall geht."
  (interactive)
  (cond
   ((and (bound-and-true-p lsp-mode) (use-region-p)
         (lsp-feature? "textDocument/rangeFormatting"))
    (lsp-format-region (region-beginning) (region-end)))
   ((and (bound-and-true-p lsp-mode)
         (lsp-feature? "textDocument/formatting"))
    (lsp-format-buffer))
   (t (call-interactively #'+format/region-or-buffer))))

;; SPC c f = IntelliJ-Formatierung (JDT-Profil), SPC c F = generisches
;; Format-Buffer/Region (Dooms apheleia-Default).
(map! :leader
      :desc "Format (IntelliJ-Profil)" "c f" #'+format/intellij
      :desc "Format buffer/region"     "c F" #'+format/region-or-buffer)


;;; --------------------------------------------------------------------------
;;; 3. Maven-Tooling (Transient-Menue)
;;; --------------------------------------------------------------------------

(defun +mvn--root ()
  "Reactor-Wurzel = das OBERSTE pom.xml in der Verzeichniskette (nicht das naechste).
WICHTIG: `locate-dominating-file' liefert nur das *naechste* pom.xml -- in einem
Multi-Modul-Projekt also das Modul-pom (z.B. entscheidungen-webapp). Baut man von dort,
wird das Modul ISOLIERT gegen veraltete ~/.m2-JARs der Geschwister kompiliert -> Fehler
wie \"Symbol nicht gefunden\" oder nicht-exhaustive Switches, obwohl IntelliJ durchlaeuft.
IntelliJ baut immer aus dem Reactor-Root, damit alle Module aus dem Quellcode kommen.
Darum hier nach oben durchlaufen, bis kein hoeheres pom.xml mehr existiert."
  (let ((dir default-directory) (root nil) hit)
    (while (and dir (setq hit (locate-dominating-file dir "pom.xml")))
      (setq root hit)
      (let ((parent (file-name-directory (directory-file-name hit))))
        ;; nil, sobald wir die Dateisystemwurzel erreichen -> Schleife endet sauber:
        (setq dir (unless (equal parent hit) parent))))
    (or root (doom-project-root) default-directory)))

(defun +mvn--module ()                                   ; Modul der aktuellen Datei (rel. zur Wurzel)
  (when-let* ((f (buffer-file-name))
              (m (locate-dominating-file f "pom.xml")))
    (directory-file-name (file-relative-name m (+mvn--root)))))

(defun +mvn-run (goals &optional this-module)            ; mvn-Aufruf via compile-Buffer
  (let* ((default-directory (+mvn--root))
         (args (string-join (transient-args '+mvn/menu) " "))
         (pl (if (and this-module (+mvn--module))
                 (format "-pl %s -am " (+mvn--module)) "")))
    (compile (format "mvn %s%s %s" pl args goals))))

(transient-define-prefix +mvn/menu ()
  "Maven-Lifecycle und -Goals fuer das aktuelle Projekt/Modul."
  ["Flags"
   ("-o" "offline" "-o")                                  ; ohne Netzwerk bauen
   ("-s" "skip tests" "-DskipTests")                       ; Tests ueberspringen
   ("-T" "parallel" "-T 1C")]                              ; parallel (1 Thread/Core)
  ["Reactor (ganzes Projekt)"
   ("c" "compile"         (lambda () (interactive) (+mvn-run "compile")))
   ("t" "test"            (lambda () (interactive) (+mvn-run "test")))
   ("i" "install"         (lambda () (interactive) (+mvn-run "install")))
   ("C" "clean install"   (lambda () (interactive) (+mvn-run "clean install")))
   ("v" "verify"          (lambda () (interactive) (+mvn-run "verify")))
   ("d" "deploy"          (lambda () (interactive) (+mvn-run "deploy")))
   ("D" "dependency:tree" (lambda () (interactive) (+mvn-run "dependency:tree")))]
  ["Nur aktuelles Modul (-pl <modul> -am)"
   ("mc" "compile" (lambda () (interactive) (+mvn-run "compile" t)))
   ("mi" "install" (lambda () (interactive) (+mvn-run "install" t)))]
  ["Rebuild / Frei / LSP"
   ("b" "Rebuild Project (clean install -DskipTests)" +mvn/rebuild-project)
   ("e" "Goal selbst eingeben (Execute Maven Goal)" +mvn/execute-goal)
   ("u" "Maven neu importieren" lsp-java-update-project-configuration)])

;; --- "Execute Maven Goal" (wie IntelliJ): beliebiges Goal eingeben + ausfuehren ---
(defvar +mvn/goal-history nil
  "Verlauf der via `+mvn/execute-goal' eingegebenen Maven-Goals (zeigt \"Recent\").")

(defvar +mvn/common-goals
  '("clean compile" "clean install" "clean install -DskipTests"
    "clean package -DskipTests" "compile" "test" "verify" "install"
    "dependency:tree" "-version")
  "Vorschlaege fuer `+mvn/execute-goal' (zusaetzlich zum Verlauf).")

;;;###autoload
(defun +mvn/execute-goal (goal &optional this-module)
  "Beliebiges Maven-Goal eingeben und ausfuehren (wie IntelliJ \"Execute Maven Goal\").
Oeffnet ein Eingabefenster (completing-read) mit Verlauf + haeufigen Goals; der
getippte Text wird 1:1 als `mvn <goal>' im Reactor-Root ausgefuehrt.
Mit Praefix-Arg (\\[universal-argument]) im Modul der aktuellen Datei (-pl <modul> -am)."
  (interactive
   (list (completing-read "mvn "
                          (delete-dups (append +mvn/goal-history
                                               (copy-sequence +mvn/common-goals)))
                          nil nil nil '+mvn/goal-history)
         current-prefix-arg))
  (let* ((root (directory-file-name (expand-file-name (+mvn--root))))
         ;; Modul VOR dem Rebind von default-directory bestimmen:
         (pl   (if (and this-module (+mvn--module))
                   (format "-pl %s -am " (+mvn--module)) ""))
         (default-directory (file-name-as-directory root)))
    (compile (format "cd %s && mvn %s %s%s"
                     (shell-quote-argument root)
                     +idea--mvn-ssl-flags pl goal))))

;; --- "Rebuild Project" (wie IntelliJ): ganzes Projekt von Grund auf neu bauen ---
(defvar +mvn-rebuild-goals "clean install -DskipTests"
  "Maven-Goals fuer `+mvn/rebuild-project' (IntelliJ \"Rebuild Project\").
`clean' wirft alle target/-Ausgaben weg, `install' baut den kompletten Reactor neu
und legt die Module in ~/.m2 ab. Tests werden uebersprungen (wie bei IntelliJ-Build).")

;;;###autoload
(defun +mvn/rebuild-project ()
  "Ganzes Projekt von Grund auf neu bauen -- Aequivalent zu IntelliJ \"Rebuild Project\".
Laeuft `mvn clean install -DskipTests' ueber den kompletten Reactor im Projekt-Root
(siehe `+mvn-rebuild-goals'). Danach ggf. `SPC m u' fuer JDT.LS-Reimport."
  (interactive)
  (let* ((root (directory-file-name (expand-file-name (+mvn--root))))
         (default-directory (file-name-as-directory root)))
    (message "Rebuild Project: mvn %s (kompletter Reactor) -- das dauert ..." +mvn-rebuild-goals)
    (compile (format "cd %s && mvn -Pent-dev %s %s"
                     (shell-quote-argument root)
                     +idea--mvn-ssl-flags +mvn-rebuild-goals))))


;;; --------------------------------------------------------------------------
;;; 4. Run/Debug-Picker aus .idea/runConfigurations
;;; --------------------------------------------------------------------------
;; Liest die IntelliJ-Run-Configs (Typ "Application") des Projekts und bietet
;; sie wie "find file" per completing-read an. Danach Auswahl Run vs. Debug.

(defun +idea--project-root ()                            ; Projektwurzel = naechstes Verzeichnis mit .idea
  ;; expand-file-name loest "~" auf und macht den Pfad absolut (sonst scheitert spaeter cd/compile).
  (expand-file-name
   (or (when-let* ((start (or buffer-file-name default-directory)))
         (locate-dominating-file start ".idea"))          ; vom aktuellen Puffer nach oben suchen
       (doom-project-root)                                 ; Fallback: Projectile/Doom-Projektwurzel
       default-directory)))

(defun +idea--run-config-dir ()                          ; .idea/runConfigurations des Projekts
  (when-let* ((root (+idea--project-root))
              (d (expand-file-name ".idea/runConfigurations" root)))
    (when (file-directory-p d) d)))

(defun +idea--parse-application (conf)                   ; relevante Felder einer Application-Config
  (let (envs opts)
    (dolist (c (dom-children conf))
      (pcase (and (consp c) (dom-tag c))
        ('option (push (cons (dom-attr c 'name) (dom-attr c 'value)) opts))
        ('module (push (cons "MODULE" (dom-attr c 'name)) opts))
        ('envs   (dolist (e (dom-by-tag c 'env))
                   (push (cons (dom-attr e 'name) (dom-attr e 'value)) envs)))))
    (list :main   (alist-get "MAIN_CLASS_NAME" opts nil nil #'equal)
          :module (alist-get "MODULE" opts nil nil #'equal)
          :vmargs (alist-get "VM_PARAMETERS" opts nil nil #'equal)
          :wd     (alist-get "WORKING_DIRECTORY" opts nil nil #'equal)
          :envs   (nreverse envs))))

(defun +idea-run-configs ()                              ; Alist (Name . Plist) aller Application-Configs
  (let (result)
    (when-let ((dir (+idea--run-config-dir)))
      (dolist (file (directory-files dir t "\\.xml\\'"))
        (with-temp-buffer
          (insert-file-contents file)
          (when-let* ((dom (libxml-parse-xml-region (point-min) (point-max)))
                      (conf (car (dom-by-tag dom 'configuration))))
            (when (equal (dom-attr conf 'type) "Application")
              (push (cons (dom-attr conf 'name) (+idea--parse-application conf)) result))))))
    (nreverse result)))

(defun +idea--expand-wd (cfg)                            ; $PROJECT_DIR$ aufloesen -> absoluter Pfad
  (when-let ((wd (plist-get cfg :wd)))
    (expand-file-name
     (replace-regexp-in-string "\\$PROJECT_DIR\\$"
                               (directory-file-name (+idea--project-root))
                               wd))))

(defvar +idea-extra-classpath-dirs '("src/test/resources/conf")
  "Zusaetzliche Verzeichnisse (relativ zum Arbeitsverzeichnis der Run-Config), die
beim dap-Start (SPC m r) VORNE auf den Classpath gelegt werden.

Hintergrund: Das Maven-Profil `ent-dev' (entscheidungen-webapp/pom.xml) haengt
`src/test/resources/conf' als <resource> an und legt dessen Inhalt so auf den
Classpath-ROOT -- dort liegt `ent.application.properties' mit `ent.db.server',
`ent.db.database' usw. IntelliJ hat dieses Profil angehakt; JDT.LS/dap kennen es
NICHT. Ohne diese Dateien bricht Spring mit \"Could not resolve placeholder
'ent.db.server'\" ab. Darum wird das Verzeichnis hier explizit ergaenzt.")

(defun +idea--resolve-classpath (main module)
  "Von JDT.LS aufgeloesten Classpath (Vector) fuer MAIN/MODULE holen, sonst nil."
  (ignore-errors
    (cl-second
     (with-lsp-workspace (lsp-find-workspace 'jdtls)
       (lsp-send-execute-command "vscode.java.resolveClasspath"
                                 (vector main module))))))

(defun +idea--launch (name cfg debug)                    ; via dap-java starten (debug=nil -> reiner Run)
  (require 'dap-java)
  ;; dap-java braucht einen laufenden JDT.LS (fuer resolveClasspath/-MainClass):
  ;; JDT.LS muss IRGENDWO laufen (nicht zwingend im aktuellen Buffer) -- so klappt der
  ;; Start auch aus dem *compilation*-Sentinel (Build-before-run) und aus Nicht-Java-Buffern.
  (unless (or (and (fboundp 'lsp-workspaces) (lsp-workspaces))
              (ignore-errors
                (seq-some (lambda (w) (eq (lsp--client-server-id (lsp--workspace-client w)) 'jdtls))
                          (lsp--session-workspaces (lsp-session)))))
    (user-error "Kein JDT.LS aktiv -- erst eine .java-Datei oeffnen und JDT.LS importieren lassen (Modeline/M-x lsp), oder den Jetty-Weg nehmen: SPC m R (mvn exec:java)"))
  (let* ((wd (+idea--expand-wd cfg))
         ;; ent-dev-conf (o.ae.) VOR den JDT-Classpath haengen, damit
         ;; ent.application.properties (ent.db.server ...) im Classpath-Root liegt:
         (extra (when wd
                  (seq-filter #'file-directory-p
                              (mapcar (lambda (d) (expand-file-name d wd))
                                      +idea-extra-classpath-dirs))))
         (tmpl (list :type "java" :request "launch" :name name
                     :mainClass   (plist-get cfg :main)
                     :projectName (plist-get cfg :module)
                     :vmArgs      (or (plist-get cfg :vmargs) "")
                     :cwd         wd
                     :env         (plist-get cfg :envs))))   ; alist (KEY . VALUE), von dap unterstuetzt
    ;; Nur wenn Extra-Dirs existieren UND JDT den Basis-Classpath liefert, setzen wir
    ;; :classPaths selbst (extra + aufgeloest). Sonst laesst dap-java ihn wie gehabt
    ;; selbst aufloesen (dann ohne Extra-Dirs -> Fallback SPC m R nutzen).
    (when extra
      (when-let ((resolved (+idea--resolve-classpath (plist-get cfg :main)
                                                     (plist-get cfg :module))))
        (setq tmpl (plist-put tmpl :classPaths
                              (vconcat (apply #'vector extra) resolved)))))
    (dap-debug (if debug tmpl (append tmpl (list :noDebug t))))))

(defun +idea--pick-config ()                             ; Picker: Name -> Plist
  (let* ((configs (+idea-run-configs)))
    (unless configs
      (user-error "Keine Application-Run-Configs in %s.idea/runConfigurations gefunden"
                  (abbreviate-file-name (+idea--project-root))))
    (let ((name (completing-read "Run-Config: " (mapcar #'car configs) nil t)))
      (cons name (cdr (assoc name configs))))))

(defvar +idea--last-run nil
  "Plist des zuletzt gestarteten Laufs -- fuer `+idea/rerun'.
Form: (:kind dap|mvn :name STRING :cfg PLIST :debug BOOL).")

(defun +idea--remember-run (kind name cfg debug)
  "Letzten Lauf fuer den Rerun merken."
  (setq +idea--last-run (list :kind kind :name name :cfg cfg :debug debug)))

(defvar +idea-build-before-run nil
  "STANDARD: nil (AUS). Wenn non-nil, kompiliert `SPC m r' (dap-java) VOR dem Start das Modul samt seiner
Reactor-Abhaengigkeiten -- genau wie IntelliJs \"Build before run\" in jeder Run-Config.
Hintergrund: dap-java startet mit dem von JDT.LS aufgeloesten Classpath. Fuer
Reactor-Geschwister-Module zeigt der auf deren `target/classes' (NICHT auf ~/.m2).
Sind die nicht/veraltet kompiliert -> `NoClassDefFoundError'/`ClassNotFoundException'
zur Laufzeit (z.B. `ApiEntscheidungAnhang'). Der Build (mvn -pl MODUL -am compile)
frischt genau diese `target/classes' auf. Auf nil setzen fuer den schnellsten Start
ohne Vor-Build (nur sinnvoll, wenn bereits alles kompiliert ist).
Bewusst auf nil gesetzt: der Start lief sonst im *compilation*-Sentinel (nach dem
Build) OHNE Java-Buffer-Kontext -> Guard meldete faelschlich \"Kein JDT.LS aktiv\".
Wer den Vor-Build will: t setzen (Guard ist jetzt buffer-unabhaengig repariert),
oder vorher einmalig `SPC m c' / `mvn compile' laufen lassen.")

(defun +idea--build-command (cfg)
  "Maven-Build-Kommando (compile) fuer Run-Config CFG: Modul + Upstream-Module (-am).
Kompiliert inkrementell (kein clean) aus dem Reactor-Root -- entspricht IntelliJs
inkrementellem \"Build\" vor dem Run. Test-Code wird uebersprungen."
  (let* ((root   (directory-file-name (+idea--project-root)))
         (module (or (plist-get cfg :module) ".")))
    (format "cd %s && mvn -Pent-dev %s -pl %s -am -Dmaven.test.skip=true compile"
            (shell-quote-argument root) +idea--mvn-ssl-flags
            (shell-quote-argument module))))

(defun +idea--compile-then (cmd on-success)
  "CMD im *compilation*-Buffer ausfuehren; NUR bei Erfolg ON-SUCCESS (0-arg) aufrufen.
So startet der Run (dap) erst, wenn der Vor-Build fehlerfrei durchlief -- wie IntelliJ,
das bei Build-Fehlern den Start abbricht und die Fehler zeigt."
  (let ((buf (compilation-start cmd)))
    (letrec ((fn (lambda (b status)
                   (when (eq b buf)
                     (remove-hook 'compilation-finish-functions fn)
                     (if (string-match-p "finished" status)
                         (funcall on-success)
                       (message "Build before run: FEHLGESCHLAGEN -- Start abgebrochen (siehe %s)"
                                (buffer-name buf)))))))
      (add-hook 'compilation-finish-functions fn))))

(defun +idea--launch-maybe-build (name cfg debug)
  "Wie IntelliJ \"Build before run\": erst kompilieren (falls `+idea-build-before-run'),
bei Erfolg via dap-java starten. Sonst direkt starten."
  (if +idea-build-before-run
      (let ((default-directory (directory-file-name (+idea--project-root))))
        (message "Build before run: kompiliere %s + Reactor-Abhaengigkeiten ..."
                 (or (plist-get cfg :module) "Projekt"))
        (+idea--compile-then
         (+idea--build-command cfg)
         (lambda () (+idea--launch name cfg debug))))
    (+idea--launch name cfg debug)))

;;;###autoload
(defun +idea/run ()
  "IntelliJ-Run-Config auswaehlen und ueber dap-java starten (Run oder Debug).
Kompiliert vorher das Modul + Reactor-Abhaengigkeiten (\"Build before run\", siehe
`+idea-build-before-run') -- verhindert `NoClassDefFoundError' durch veraltete
`target/classes' von Geschwister-Modulen."
  (interactive)
  (let* ((pick (+idea--pick-config))
         (debug (string= "Debug" (completing-read "Aktion: " '("Run" "Debug") nil t))))
    (+idea--remember-run 'dap (car pick) (cdr pick) debug)
    (+idea--launch-maybe-build (car pick) (cdr pick) debug)))

;; --- Fallback: Start ueber 'mvn exec:java' (zuverlaessig fuer den Jetty-Starter) ---
;; Spiegelt die bewaehrte alte ent/run-Logik: Profil ent-dev, SSL-Flags, Env als
;; Prozessumgebung, VM-Parameter via MAVEN_OPTS. Debug haengt JDWP an (Port 5005).

(defvar +idea-build-dependencies t
  "Wenn non-nil, vor dem Start die abhaengigen Reactor-Module bauen+installieren.
Entspricht IntelliJs \"Build before run\": baut das Modul samt aller von ihm
benoetigten Geschwister-Module (mvn -am) aus dem lokalen Quellcode und legt sie in
~/.m2 ab. Noetig, wenn z.B. model/service lokal geaendert wurden und Nexus nicht
erreichbar ist (sonst kompiliert die webapp gegen veraltete ~/.m2-JARs -> \"Symbol
nicht gefunden\"). Auf nil setzen fuer den schnellen Pfad (nur das Modul selbst;
setzt voraus, dass ~/.m2 aktuell ist).")

;; Flags, damit Nexus trotz unbekanntem Zertifikat erreichbar bleibt: Maven 3.9 nutzt
;; den nativen Resolver-Transport, fuer den die wagon-ssl-Flags nicht greifen -- daher
;; explizit auf den wagon-Transport zwingen (sonst: PKIX path building failed).
(defconst +idea--mvn-ssl-flags
  "-Dmaven.resolver.transport=wagon -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true")

(defun +idea--mvn-command (cfg debug)
  "Shell-Kommando fuer eine Run-Config bauen.
Optional Phase 1: abhaengige Module via -am bauen+installieren.
Phase 2: im Modul-Arbeitsverzeichnis ueber exec:java starten (Env + MAVEN_OPTS = Laufzeit)."
  (let* ((root   (directory-file-name (+idea--project-root)))   ; Reactor-Root (mit Parent-pom)
         (module (or (plist-get cfg :module) "."))              ; z.B. "entscheidungen-webapp"
         (wd     (or (+idea--expand-wd cfg) root))              ; Arbeitsverzeichnis fuer den Run
         (envs (mapconcat (lambda (kv) (shell-quote-argument (format "%s=%s" (car kv) (cdr kv))))
                          (plist-get cfg :envs) " "))
         (vm  (concat (or (plist-get cfg :vmargs) "")
                      (when debug
                        " -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005")))
         ;; Phase 1: Geschwister-Module aus lokalem Quellcode bauen + nach ~/.m2 installieren.
         (build (when +idea-build-dependencies
                  (format "cd %s && mvn -Pent-dev %s -pl %s -am -Dmaven.test.skip=true install && "
                          (shell-quote-argument root) +idea--mvn-ssl-flags
                          (shell-quote-argument module))))
         ;; Phase 2: im Arbeitsverzeichnis ueber exec:java starten.
         ;; WICHTIG - Profil `ent-dev' liefert die DB-Defaults:
         ;; Das Maven-Profil `ent-dev' (entscheidungen-webapp/pom.xml) haengt
         ;; `src/test/resources/conf' als <resource> an -> dessen Inhalt (u.a.
         ;; `ent.application.properties' mit `ent.db.server=localhost') landet im
         ;; Classpath-ROOT von target/classes. Ohne dieses Profil bricht Spring mit
         ;; "Could not resolve placeholder 'ent.db.server'" ab. `compile' fuehrt
         ;; `process-resources' aus und kopiert die conf entsprechend; classpathScope=compile
         ;; (NICHT test -- sonst landen Test-Abhaengigkeiten wie h2/junit auf dem
         ;; Laufzeit-Classpath, was IntelliJ ebenfalls nicht tut).
         (run (format "cd %s && env %s MAVEN_OPTS=%s mvn -Pent-dev %s compile exec:java -Dexec.mainClass=%s -Dexec.classpathScope=compile"
                      (shell-quote-argument wd) envs (shell-quote-argument vm)
                      +idea--mvn-ssl-flags
                      (shell-quote-argument (plist-get cfg :main)))))
    (concat build run)))

(defun +idea--mvn-launch (cfg debug)
  "Run-Config CFG ueber 'mvn exec:java' im richtigen Arbeitsverzeichnis starten."
  (let ((default-directory (file-name-as-directory
                            (or (+idea--expand-wd cfg) (+idea--project-root)))))
    (unless (file-directory-p default-directory)
      (user-error "Arbeitsverzeichnis existiert nicht: %s" default-directory))
    (when +idea-build-dependencies
      (message "Baue zuerst abhaengige Module (mvn -am install) -- das kann beim ersten Mal dauern ..."))
    (compile (+idea--mvn-command cfg debug))
    (when debug
      (message "JDWP auf :5005 -- sobald Jetty laeuft, mit `SPC m a' (+idea/attach) verbinden."))))

;;;###autoload
(defun +idea/run-mvn ()
  "Run-Config ueber 'mvn exec:java' starten (Fallback fuer den Jetty-Starter).
Baut bei `+idea-build-dependencies' zuerst die abhaengigen Module (mvn -am install),
damit die webapp nicht gegen veraltete ~/.m2-JARs kompiliert.
Bei Debug wird JDWP auf Port 5005 geoeffnet -- danach mit `+idea/attach' verbinden."
  (interactive)
  (let* ((pick (+idea--pick-config))
         (cfg  (cdr pick))
         (debug (string= "Debug" (completing-read "Aktion: " '("Run" "Debug") nil t))))
    (+idea--remember-run 'mvn (car pick) cfg debug)
    (+idea--mvn-launch cfg debug)))

(defun +idea--descendant-pids (pid)
  "Liste ALLER Nachfahren-PIDs von PID (rekursiv, tiefste zuerst)."
  (let ((kids (ignore-errors
                (mapcar #'string-to-number
                        (split-string
                         (shell-command-to-string (format "pgrep -P %d" pid))
                         nil t)))))
    (append (apply #'append (mapcar #'+idea--descendant-pids kids)) kids)))

(defun +idea--kill-process-tree (proc)
  "PROC und ALLE Nachfahren (Shell -> mvn -> java/Jetty) hart per SIGKILL beenden.
Noetig, damit gebundene Ports (HTTP bzw. JDWP :5005) sofort frei werden -- sonst
scheitert ein direkt folgender Rerun mit \"address already in use\", weil `mvn'/
`java' als Waisenkind weiterlaeuft (SIGINT an die Shell reicht NICHT)."
  (when (process-live-p proc)
    (let* ((pid  (process-id proc))
           (pids (when pid (append (+idea--descendant-pids pid) (list pid)))))
      (dolist (pp pids)
        (ignore-errors (signal-process pp 'KILL))))))

;; Re-`compile' (Rerun/SPC m R) soll einen noch laufenden Prozess ohne Rueckfrage
;; beenden, statt "A compilation process is running; kill it?" zu fragen:
(setq compilation-always-kill t)

;;;###autoload
(defun +idea/stop-run ()
  "Laufenden Run/Debug SOFORT stoppen -- egal aus welchem Buffer heraus.
dap-Sessions werden STATUS-basiert erkannt (`dap--session-running') -- `program-proc'
ist bei Java-Launch nil, weil die JVM vom Debug-Adapter (nicht von Emacs) gestartet
wird. Beendet wird NICHT-blockierend: `dap-disconnect' ist async und weist den Adapter
an, die JVM zu terminieren; danach wird der Status sofort auf `terminated' gesetzt und
die Session verzoegert aufgeraeumt -- so wird das SYNCHRONE `dap-request' aus
`dap-delete-session' (das Emacs bei haengendem Jetty einfriert) vermieden. Zusaetzlich
werden laufende Compilation-/`mvn exec:java'-Prozesse (SPC m R) beendet."
  (interactive)
  (let ((n 0))
    ;; 1. dap-Sessions (SPC m r): Status-basiert erkennen und nicht-blockierend beenden.
    (when (and (featurep 'dap-mode) (fboundp 'dap--get-sessions))
      (dolist (s (dap--get-sessions))
        (when (ignore-errors (dap--session-running s))
          (setq n (1+ n))
          ;; async! terminiert die JVM ueber den Adapter, ohne auf Antwort zu warten:
          (ignore-errors (dap-disconnect s))
          ;; falls dap den Prozess doch selbst gestartet hat: hart killen.
          (when-let ((proc (ignore-errors (dap--debug-session-program-proc s))))
            (when (process-live-p proc) (ignore-errors (kill-process proc))))
          ;; Status sofort auf terminated -> spaeteres Aufraeumen nimmt den schnellen Pfad:
          (ignore-errors (setf (dap--debug-session-state s) 'terminated))))
      ;; Aufraeumen (Session aus Liste, Output-Buffer schliessen) verzoegert & nicht-blockierend:
      (run-at-time
       0.5 nil
       (lambda ()
         (when (fboundp 'dap--get-sessions)
           (dolist (s (dap--get-sessions))
             (unless (ignore-errors (dap--session-running s))
               (ignore-errors (dap-delete-session s))))))))
    ;; 2. Compilation-/exec:java-Prozesse (SPC m R): den GANZEN Prozessbaum killen.
    ;; `kill-compilation' schickt nur SIGINT an die Shell -- das Kind `mvn'/`java'
    ;; (exec:java laeuft IN dieser JVM, Jetty haengt hier) ueberlebt sonst als Waise
    ;; und haelt den Port weiter, sodass der Rerun scheitert.
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (and (derived-mode-p 'compilation-mode)
                   (get-buffer-process buf))
          (ignore-errors (+idea--kill-process-tree (get-buffer-process buf)))
          (setq n (1+ n)))))
    (message (if (> n 0)
                 (format "Run gestoppt (%d Prozess/e beendet)." n)
               "Kein laufender Run gefunden (dap-Session/Compilation)."))))

;;;###autoload
(defun +idea/rerun ()
  "Letzten Lauf (SPC m r / SPC m R) ohne erneute Auswahl neu starten.
Stoppt vorher -- wie IntelliJs Rerun -- einen noch laufenden Lauf und startet dann
dieselbe Run-Config mit derselben Aktion (Run/Debug bzw. mvn exec:java) neu."
  (interactive)
  (unless +idea--last-run
    (user-error "Noch kein Run gestartet -- erst SPC m r (dap) oder SPC m R (mvn)"))
  (let ((kind  (plist-get +idea--last-run :kind))
        (name  (plist-get +idea--last-run :name))
        (cfg   (plist-get +idea--last-run :cfg))
        (debug (plist-get +idea--last-run :debug)))
    (+idea/stop-run)
    ;; kurze Pause, damit Prozess/Port frei werden, dann denselben Lauf neu starten:
    (run-at-time
     1.5 nil
     (lambda ()
       (message "Rerun: %s (%s)" name
                (if (eq kind 'mvn) "mvn exec" (if debug "Debug" "Run")))
       (pcase kind
         ('dap (+idea--launch-maybe-build name cfg debug))
         ('mvn (+idea--mvn-launch cfg debug)))))))

(defvar +java--hotswap-pending nil
  "Wenn non-nil, nutzt der naechste `hotcodereplace'-Handler das Event fuer einen HotSwap.
Wird von `+java/hotswap' gesetzt -- so laeuft HotSwap nur auf Zuruf, nicht bei jedem Save.")

(defun +java--redefine-now (session)
  "Geaenderte Klassen SOFORT per `redefineClasses' in SESSION laden.
Setzt voraus, dass JDT.LS die Quellen bereits (beim Speichern) kompiliert hat.

WICHTIG: Der dap-Response-Callback bekommt die KOMPLETTE Nachricht; die Nutzdaten
liegen unter `body' -> `changedClasses'. (Das falsch verschachtelte Auslesen auf
oberster Ebene -- wie in lsp-java -- ergibt immer `nil' und meldet faelschlich
\"keine Klassen\".)"
  (dap--send-message
   (dap--make-request "redefineClasses")
   (lambda (resp)
     (let* ((ok      (and (hash-table-p resp) (gethash "success" resp)))
            (body    (and (hash-table-p resp) (gethash "body" resp)))
            (classes (and (hash-table-p body) (gethash "changedClasses" body)))
            (errmsg  (and (hash-table-p resp) (gethash "message" resp))))
       (cond
        ((and classes (> (length classes) 0))
         (message "HotSwap OK: %d Klasse(n) neu geladen: %s"
                  (length classes)
                  (mapconcat #'identity (append classes nil) ", ")))
        ((not ok)
         (message "HotSwap fehlgeschlagen: %s" (or errmsg "unbekannter Fehler")))
        (t
         (message "HotSwap: keine geaenderten Klassen -- JDT hat seit dem letzten Lauf/HotSwap nichts neu kompiliert (oder strukturelle Aenderung -> Neustart noetig).")))))
   session))

(after! dap-mode
  (require 'dap-java)
  ;; "Remote JVM Debug"-Aequivalent (an laufende JVM mit JDWP :5005 andocken):
  (dap-register-debug-template
   "ENT attach :5005"
   (list :type "java" :request "attach" :hostName "localhost" :port 5005))

  ;; HotSwap NICHT bei jedem Save: dap-java wuerde sonst bei JEDEM Speichern die
  ;; geaenderten Klassen in die JVM schieben (`dap-java-hot-reload' Default `always').
  ;; Das ist zu viel Gerechne, wenn man erst mehrere Changes machen will. Darum:
  ;;   - `dap-java-hot-reload' auf `never' -> Speichern allein schiebt NICHTS mehr.
  ;;   - HotSwap nur auf Zuruf ueber `+java/hotswap' (SPC m h): das setzt
  ;;     `+java--hotswap-pending' und speichert; JDT.LS kompiliert inkrementell und
  ;;     feuert dann `hotcodereplace' -> erst DANN werden die Klassen geladen.
  (setq dap-java-hot-reload 'never)
  (cl-defmethod dap-handle-event ((_event (eql hotcodereplace)) session _params)
    (when (or (eq dap-java-hot-reload 'always) +java--hotswap-pending)
      (setq +java--hotswap-pending nil)
      (+java--redefine-now session))))

;;; --------------------------------------------------------------------------
;;; Debug-Toolbar (dap-ui-controls) NUR bei Halt am Breakpoint einblenden
;;; --------------------------------------------------------------------------
;; Standardmaessig zeigt dap die schwebende Steuerungs-Leiste (Step/Continue/Stop)
;; die GANZE Debug-Session ueber. Gewuenscht ist IntelliJ-Verhalten: Die Leiste
;; erscheint nur, wenn die Ausfuehrung an einem Breakpoint STEHT, und verschwindet
;; beim Weiterlaufen bzw. beim Session-Ende wieder.
;;
;; WARUM DAS FRUEHER "RANDOM" AUFPOPPTE (analysiert in dap-mode 0.x, dap-ui.el:558):
;;   `dap-ui--update-controls' zeigt die Leiste, sobald `dap--session-running' t
;;   liefert -- und das prueft NUR das Statusfeld der Session ("nicht terminated
;;   und nicht failed"), niemals ob wirklich am Breakpoint gehalten wird oder ob
;;   der Prozess noch lebt. Eine aus einem frueheren Lauf uebrig gebliebene
;;   Session (JVM laeuft noch, Socket offen, Status `running') gilt damit als
;;   aktiv. Gleichzeitig registriert `dap-ui-controls-mode' seinen Updater u.a.
;;   auf `dap-session-changed-hook' -- der feuert an vielen Stellen, z.B. beim
;;   Setzen/Loeschen von Breakpoints (dap--set-sessions) oder bei Thread-Events.
;;   Blieb der Mode nach einem abnormal beendeten Lauf "scharf" (kein
;;   terminated-Event -> unser Ausschalt-Hook lief nie), genuegte irgendein
;;   solcher Hook, damit die Leiste ohne erkennbaren Anlass wieder erschien.
;;
;; FIX: Nicht auf das Ein-/Ausschalten des Modes verlassen, sondern die Sichtbar-
;; keit an der Wurzel erzwingen -- die Leiste wird NUR gezeigt, wenn die aktuelle
;; Session laeuft UND einen aktiven Stackframe hat. Genau dieses Feld ist der
;; verlaessliche "steht am Breakpoint"-Indikator: gesetzt beim Anspringen des
;; Frames (dap-mode.el:818), auf nil zurueckgesetzt beim Weiterlaufen (:686).

(after! dap-mode
  ;; `controls' aus der Auto-Konfiguration nehmen -> nicht mehr automatisch beim
  ;; Session-Start aktiv (locals/breakpoints/expressions/tooltip bleiben erhalten):
  (setq dap-auto-configure-features
        (delq 'controls dap-auto-configure-features)))

(after! dap-ui
  (defun +dap--halted-p ()
    "Non-nil, wenn die aktuelle Debug-Session wirklich an einem Breakpoint steht."
    (let ((session (ignore-errors (dap--cur-session))))
      (and session
           (dap--session-running session)
           (dap--debug-session-active-frame session)
           t)))

  (defun +dap--controls-only-when-halted-a (orig &rest args)
    "Leiste nur beim Halt am Breakpoint zeigen, sonst hart verstecken.
Ersetzt die Upstream-Bedingung `running?' durch `+dap--halted-p'."
    (if (+dap--halted-p)
        (apply orig args)
      (ignore-errors (posframe-hide dap-ui--control-buffer))))

  (advice-add 'dap-ui--update-controls :around #'+dap--controls-only-when-halted-a)

  (defun +dap/controls-on (&rest _)
    "Debug-Toolbar scharfschalten (Session gestartet / Halt am Breakpoint).
Sichtbar wird sie dadurch noch nicht -- das entscheidet die Advice oben."
    (unless (bound-and-true-p dap-ui-controls-mode)
      (dap-ui-controls-mode 1)))

  (defun +dap/controls-off (&rest _)
    "Debug-Toolbar ausblenden und abschalten (Weiterlaufen / Session-Ende)."
    (when (bound-and-true-p dap-ui-controls-mode)
      (dap-ui-controls-mode -1))
    (ignore-errors (posframe-hide dap-ui--control-buffer)))

  (defun +dap/controls-reset ()
    "Notfall-Reset: Debug-Toolbar sofort ausblenden und abschalten.
Nur noetig, falls doch mal eine Leiste haengen bleibt (z.B. nach einem hart
abgeschossenen Debug-Prozess)."
    (interactive)
    (+dap/controls-off)
    (message "Debug-Toolbar ausgeblendet"))

  ;; Hooks werden mit dem debug-session-Objekt aufgerufen -> Argument ignorieren.
  ;; Scharfschalten schon beim Session-Start: `dap-stopped-hook' feuert, BEVOR der
  ;; Stackframe geholt ist (dap-mode.el:838 vs. :818) -- der Mode muss also vorher
  ;; stehen, damit der spaetere `dap-stack-frame-changed-hook' die Leiste zeigt.
  (add-hook 'dap-session-created-hook #'+dap/controls-on)
  (add-hook 'dap-stopped-hook         #'+dap/controls-on)
  (add-hook 'dap-terminated-hook      #'+dap/controls-off))


;;; --------------------------------------------------------------------------
;;; Debug-Keybindings (dap-mode) auf SPC d -- vollstaendiges IntelliJ-artiges Set
;;; --------------------------------------------------------------------------
;; WICHTIG: Dooms `(debugger +lsp)'-Modul legt den SPC-d-Prefix per Default auf
;; `dape' (ein anderes Debug-Paket). Dieses Setup faehrt aber komplett ueber
;; `dap-mode'/`dap-java' (Run-Config-Picker SPC m r -> `dap-debug', Tests, HotSwap,
;; Attach, Stop). Die `dape-*'-Tasten wuerden also NICHT zur laufenden dap-Session
;; passen. Darum SPC d hier vollstaendig auf die passenden `dap-mode'-Befehle mappen.
;;
;; Merkhilfe (IntelliJ-Aequivalent):
;;   Resume F9=SPC d c | Step Over F8=SPC d n | Step Into F7=SPC d i
;;   Step Out Shift+F8=SPC d o | Toggle Breakpoint Ctrl+F8=SPC d b
;;   Das Steuer-Panel mit allen Tasten in einem: SPC d h (dap-hydra).
(map! :leader
      (:prefix ("d" . "debug (dap)")
       ;; --- Session starten/stoppen ---
       :desc "Debug starten (Template)"   "d" #'dap-debug                 ; dap-Template auswaehlen
       :desc "Debug: letzten erneut"      "L" #'dap-debug-last            ; letzten Debug-Lauf erneut
       :desc "Run-Config (SPC m r)"       "R" #'+idea/run                 ; IntelliJ-Run-Config-Picker
       :desc "Session trennen/beenden"    "q" #'dap-disconnect            ; aktuelle Session beenden
       :desc "Alle Sessions stoppen"      "Q" #'+idea/stop-run            ; alles beenden (dap + mvn)
       ;; --- Ausfuehrung steuern (im Halt am Breakpoint) ---
       :desc "Weiter/Resume (F9)"         "c" #'dap-continue              ; weiterlaufen
       :desc "Step Over (F8)"             "n" #'dap-next                  ; naechste Zeile (ueberspringen)
       :desc "Step Into (F7)"             "i" #'dap-step-in               ; in Methode springen
       :desc "Step Out (Shift+F8)"        "o" #'dap-step-out              ; Methode verlassen
       :desc "Steuer-Panel (Hydra)"       "h" #'dap-hydra                 ; alle Controls in einem Transient
       ;; --- Breakpoints ---
       :desc "Breakpoint an/aus"          "b" #'dap-breakpoint-toggle     ; Breakpoint setzen/entfernen
       :desc "Alle Breakpoints loeschen"  "B" #'dap-breakpoint-delete-all
       :desc "Bedingter Breakpoint"       "C" #'dap-breakpoint-condition  ; nur bei Bedingung stoppen
       :desc "Logpoint (Nachricht)"       "l" #'dap-breakpoint-log-message; loggt statt zu stoppen
       :desc "Breakpoint-Trefferanzahl"   "H" #'dap-breakpoint-hit-condition
       ;; --- Werte inspizieren ---
       :desc "Auswerten (unter Cursor)"   "e" #'dap-eval-thing-at-point   ; Ausdruck unter Punkt
       :desc "Auswerten (eingeben)"       "E" #'dap-eval                  ; freien Ausdruck auswerten
       :desc "Watch hinzufuegen"          "w" #'dap-ui-expressions-add    ; Ausdruck dauerhaft beobachten
       :desc "REPL"                       "r" #'dap-ui-repl               ; interaktive Konsole
       ;; --- Fenster/Panels ---
       :desc "Locals/Variablen"           "v" #'dap-ui-locals            ; lokale Variablen
       :desc "Watches-Fenster"            "x" #'dap-ui-expressions       ; beobachtete Ausdruecke
       :desc "Breakpoint-Liste"           "k" #'dap-ui-breakpoints       ; alle Breakpoints
       :desc "Sessions"                   "s" #'dap-ui-sessions          ; laufende Sessions
       ;; --- Stack/Threads ---
       :desc "Stack-Frame wechseln"       "f" #'dap-switch-stack-frame
       :desc "Thread wechseln"            "t" #'dap-switch-thread))


;;;###autoload
(defun +java/hotswap ()
  "IntelliJ-HotSwap auf Zuruf: geaenderte Klassen in die LAUFENDE Debug-Session laden.
KEIN Rebuild, KEIN Neustart -- nur die geaenderten .class-Dateien werden per JDWP in
die laufende JVM geschoben. Laeuft NICHT bei jedem Save (`dap-java-hot-reload' = never),
sondern nur ueber diesen Befehl (SPC m h / SPC r h) -- so kann man erst mehrere Changes
machen und dann einmal uebernehmen.

Ablauf: geaenderte Java-Buffer speichern -> JDT.LS kompiliert inkrementell und feuert
`hotcodereplace' -> dann werden die Klassen geladen. Ist nichts offen-geaendert, wird
direkt der seit dem letzten HotSwap geaenderte Stand geladen.

Grenzen (wie in IntelliJ): HotSwap ersetzt nur Methoden-Koerper. Neue/entfernte
Methoden oder Felder, geaenderte Signaturen oder die Klassenhierarchie brauchen einen
Neustart (SPC m e)."
  (interactive)
  (require 'dap-java)
  (let ((session (dap--cur-session)))
    (unless (and session (dap--session-running session))
      (user-error "Kein laufender Debug -- HotSwap braucht eine aktive Debug-Session (SPC m r -> Debug)"))
    (let ((dirty (seq-filter
                  (lambda (b)
                    (with-current-buffer b
                      (and (buffer-file-name) (buffer-modified-p)
                           (derived-mode-p 'java-mode 'java-ts-mode))))
                  (buffer-list))))
      (if (null dirty)
          ;; nichts offen-geaendert -> direkt laden (JDT hat bei frueheren Saves kompiliert):
          (+java--redefine-now session)
        ;; sonst: pending setzen + speichern; das hotcodereplace-Event loest den Push aus.
        (setq +java--hotswap-pending t)
        (dolist (b dirty) (with-current-buffer b (save-buffer)))
        (message "HotSwap: %d Datei(en) gespeichert -- JDT kompiliert, Klassen werden geladen ..."
                 (length dirty))
        ;; Fallback, falls kein hotcodereplace-Event kommt: nach kurzer Zeit direkt pushen.
        (run-at-time
         1.5 nil
         (lambda ()
           (when +java--hotswap-pending
             (setq +java--hotswap-pending nil)
             (when-let ((s (dap--cur-session)))
               (when (dap--session-running s) (+java--redefine-now s))))))))))

;;;###autoload
(defun +idea/attach ()
  "An eine laufende JVM mit JDWP auf Port 5005 andocken (Remote-Debug)."
  (interactive)
  (require 'dap-java)
  (dap-debug (list :type "java" :request "attach" :hostName "localhost" :port 5005)))


;;; --------------------------------------------------------------------------
;;; Projekt auf Fehler pruefen (wie IntelliJ "Build Project" / Ctrl+F9)
;;; --------------------------------------------------------------------------
;; LSP/JDT.LS zeigt Fehler nur fuer GEOEFFNETE Dateien. Aendert man z.B. eine
;; Konstruktor-Signatur, sieht man die kaputten Aufrufstellen in NICHT geoeffneten
;; Dateien NICHT automatisch (anders als IntelliJ, das laufend das ganze Projekt
;; kompiliert). Dieser Befehl kompiliert einmal den GANZEN Reactor -> alle Fehler
;; projektweit ("X errors") im *compilation*-Buffer, navigierbar mit `]e'/`[e'
;; (bzw. `M-g n'/`M-g p'), RET springt zur Fehlerstelle.

;;;###autoload
(defun +java/check-project (&optional module-only)
  "Ganzen Reactor kompilieren und ALLE Fehler projektweit anzeigen (IntelliJ \"Build Project\").
Zeigt kaputte Aufrufstellen auch in NICHT geoeffneten Dateien -- z.B. nach einer
Konstruktor-/Signatur-Aenderung. Navigation im Ergebnis: `]e'/`[e' (naechster/vorheriger
Fehler), RET springt hin.

Mit Praefix-Argument (\[universal-argument]) nur das aktuelle Modul + dessen
ABHAENGIGE Module (`-pl MODUL -amd') pruefen -- schneller, findet gezielt die
Aufrufstellen einer Aenderung im aktuellen Modul (Downstream)."
  (interactive "P")
  (let* ((default-directory (+mvn--root))
         (mod (and module-only (+mvn--module)))
         (pl  (if mod (format "-pl %s -amd " (shell-quote-argument mod)) ""))
         ;; inkrementell (kein clean) fuer Tempo; test-skip, damit nur Hauptcode zaehlt:
         (cmd (format "mvn -Pent-dev %s %s-Dmaven.test.skip=true compile"
                      +idea--mvn-ssl-flags pl)))
    (message "Projekt pruefen: %s ..." (if mod (format "Modul %s + Dependents" mod) "ganzer Reactor"))
    (compile cmd)))

;;; --------------------------------------------------------------------------
;;; 5. Interface <-> Implementierung
;;; --------------------------------------------------------------------------

;;;###autoload
(defun +java/toggle-impl ()
  "Springe zwischen XService.java und XServiceImpl.java; sonst LSP-Implementations."
  (interactive)
  (let ((f (buffer-file-name)))
    (if (and f (string-match "\\.java\\'" f))
        (let ((other (if (string-match "Impl\\.java\\'" f)
                         (replace-regexp-in-string "Impl\\.java\\'" ".java" f)    ; Impl -> Interface
                       (replace-regexp-in-string "\\.java\\'" "Impl.java" f))))   ; Interface -> Impl
          (if (file-exists-p other) (find-file other)
            (call-interactively #'lsp-find-implementation)))                       ; Fallback: LSP
      (call-interactively #'lsp-find-implementation))))

;;;###autoload
(defun +java/previous-method ()
  "Zur vorherigen Methode/Definition springen (IntelliJ: Navigate Previous Method)."
  (interactive)
  (beginning-of-defun 1))

;;;###autoload
(defun +java/next-method ()
  "Zur naechsten Methode/Definition springen (IntelliJ: Navigate Next Method)."
  (interactive)
  ;; `beginning-of-defun' mit negativem Argument springt zum naechsten Defun-Anfang.
  ;; In java-ts-mode nutzt Emacs die Defun-Navigation des Tree-sitter-Modus.
  (beginning-of-defun -1))


;;; --------------------------------------------------------------------------
;;; 6. Postgres-DB-Viewer (pgmacs) -- IntelliJ-Datenbank-Tool-Aequivalent
;;; --------------------------------------------------------------------------
;; Passwoerter NICHT hier hinterlegen, sondern in ~/.authinfo(.gpg). Beispiel:
;;   machine localhost port 5432 login USER password GEHEIM
;; Ports gem. Run-Config-Envs: ent.db=5432, bas.db=5433 (Guide-Client: bas.db user=sa db=magellan).

(defvar +pg-profiles
  '(("ENT - Postgres (5432)"        . "user=ent host=localhost port=5432 dbname=Entscheidungen")
    ("BAS - Postgres (5433)"        . "user=ent host=localhost port=5433 dbname=EntscheidungenBasis")
    ("Guide-Client - magellan (5432)" . "user=sa host=localhost port=5432 dbname=magellan"))
  "Benannte Postgres-Verbindungen, analog den IntelliJ-DataSources.
Passwoerter stehen bewusst NICHT hier, sondern in ~/.authinfo(.gpg) (auth-source),
damit kein Klartext ins Git gelangt. Passendes authinfo-Format:
  machine localhost port 5432 login ent password GEHEIM")

;; --------------------------------------------------------------------------
;; WICHTIG: pg.el 0.67 hat in `pg-connect/string' einen Bug (`string-bytes' auf
;; einer LISTE -> "Wrong type argument: stringp"), der JEDEN Connection-String
;; abbrechen laesst -- dann oeffnet pgmacs KEIN Tabellen-Buffer, man sieht nur
;; "Connecting to PostgreSQL...done". Darum NICHT `pgmacs-open-string' nutzen,
;; sondern den Profil-String selbst parsen und ueber `pg-connect-plist' verbinden.
;; Das Passwort kommt aus ~/.authinfo(.gpg) (auth-source), falls nicht im String.
(defun +pg--parse-conn (conn)
  "CONN-String \"user=.. host=.. port=.. dbname=..\" -> Alist (Key . Wert)."
  (mapcar (lambda (kv)
            (let ((p (split-string kv "=" t "[ \t]")))
              (cons (car p) (cadr p))))
          (split-string conn "[ \t]+" t)))

(defun +pg--password (host port user)
  "Passwort aus ~/.authinfo(.gpg) fuer HOST/PORT/USER holen (oder nil)."
  (require 'auth-source)
  (when-let* ((m (car (auth-source-search :host host
                                          :port (and port (format "%s" port))
                                          :user user
                                          :max 1 :require '(:secret))))
              (secret (plist-get m :secret)))
    (if (functionp secret) (funcall secret) secret)))

(defun +pg--reachable-p (host port &optional timeout)
  "Nicht-blockierende TCP-Probe: ist HOST:PORT innerhalb TIMEOUT Sekunden erreichbar?
Wichtig, weil `pg-connect-plist' SYNCHRON verbindet: bei falschem/geschlossenem
Port wuerde Emacs sonst bis zum OS-TCP-Timeout (~60-75s) komplett einfrieren.
Hier per `:nowait' (asynchroner Connect) + kurzem Poll -> nie ein Freeze."
  (let* ((timeout (or timeout 3))
         (proc (ignore-errors
                 (make-network-process
                  :name "pg-probe" :host host :service port
                  :nowait t :coding 'binary))))
    (unwind-protect
        (and proc
             (let ((deadline (+ (float-time) timeout)))
               (while (and (eq (process-status proc) 'connect)
                           (< (float-time) deadline))
                 (accept-process-output proc 0.05))
               (eq (process-status proc) 'open)))
      (when proc (ignore-errors (delete-process proc))))))

(defun +pg--connect (conn)
  "Profil-CONN-String -> pg-Verbindung ueber `pg-connect-plist' (bug-freier Pfad).
Prueft VORHER per nicht-blockierender Probe, ob der Port erreichbar ist -- sonst
klare Fehlermeldung statt eingefrorenem Emacs."
  (let* ((a      (+pg--parse-conn conn))
         (dbname (cdr (assoc "dbname" a)))
         (user   (cdr (assoc "user" a)))
         (host   (or (cdr (assoc "host" a)) "localhost"))
         (port   (string-to-number (or (cdr (assoc "port" a)) "5432")))
         (pw     (or (cdr (assoc "password" a)) (+pg--password host port user))))
    (when (or (member user '(nil "USER")) (member dbname '(nil "DBNAME")))
      (user-error "Profil enthaelt noch Platzhalter/leere Werte -- bitte `+pg-profiles' mit echten user/dbname fuellen (siehe docs/datenbank.md)"))
    (unless (+pg--reachable-p host port 3)
      (user-error "DB nicht erreichbar: %s:%d (laeuft der Postgres? richtiger Port? SSH-Tunnel offen?) -- Verbindung abgebrochen, Emacs bleibt bedienbar" host port))
    (message "Verbinde mit %s:%d/%s ..." host port dbname)
    (pg-connect-plist dbname user :password pw :host host :port port)))

;;;###autoload
(defun +pg/open (&optional search-table)
  "Postgres-Profil auswaehlen (wie \='find file\=') und in pgmacs oeffnen.
Mit Praefix-Argument (\[universal-argument]) direkt in die TABELLENSUCHE springen
(wie IntelliJ Cmd+O ueber die DB): nach dem Verbinden wird sofort
`pgmacs-open-table\=' (Tabellenname per Completion) geoeffnet."
  (interactive "P")
  (let* ((name (completing-read "DB-Profil: " (mapcar #'car +pg-profiles) nil t))
         (conn (cdr (assoc name +pg-profiles))))
    (when search-table
      ;; Einmal-Hook: sobald die Tabellenliste gezeichnet ist, im richtigen
      ;; pgmacs-Buffer die Tabellensuche starten (pgmacs-open ist asynchron).
      (letrec ((fn (lambda ()
                     (remove-hook 'pgmacs-table-list-hook fn)
                     (let ((buf (current-buffer)))
                       (run-with-timer
                        0.05 nil
                        (lambda ()
                          (when (buffer-live-p buf)
                            (with-current-buffer buf
                              (call-interactively #'pgmacs-open-table)))))))))
        (add-hook 'pgmacs-table-list-hook fn)))
    (pgmacs-open (+pg--connect conn))))

;;;###autoload
(defun +pg/open-table ()
  "DB-Profil waehlen, verbinden und DIREKT die Tabellensuche oeffnen (IntelliJ-artig)."
  (interactive)
  (+pg/open t))

;;; --------------------------------------------------------------------------
;;; SQL aus einer .sql-Datei auf einem Profil ausfuehren (IntelliJ "Execute")
;;; --------------------------------------------------------------------------
;; Region markieren (oder Cursor ins Statement) -> Shortcut -> DB-Profil waehlen
;; -> das SQL wird auf dieser DB ausgefuehrt und als pgmacs-Tabelle angezeigt.
;; Der Ergebnis-Buffer ist ein pgmacs-Buffer -> hjkl-Navigation etc. gelten dort.

(defvar +pg--last-profile nil
  "Zuletzt gewaehltes DB-Profil (Vorauswahl bei `+pg/run-sql').")

(defun +pg--sql-at-point ()
  "SQL-Text: aktive Region, sonst das Statement am Punkt (zwischen `;').
Steht der Cursor direkt HINTER einem `;' (z.B. am Zeilenende), wird das gerade
beendete Statement genommen, nicht das folgende."
  (string-trim
   (if (use-region-p)
       (buffer-substring-no-properties (region-beginning) (region-end))
     (save-excursion
       (skip-chars-backward " \t\n")            ; an nachlaufendem Whitespace vorbei
       (let* ((anchor  (point))
              (at-semi (eq (char-before) ?\;))    ; sitzen wir direkt hinter einem ;?
              (end (save-excursion
                     (goto-char anchor)
                     (if at-semi anchor
                       (if (re-search-forward ";" nil t) (match-end 0) (point-max)))))
              (beg (save-excursion
                     (goto-char (if at-semi (1- anchor) anchor))
                     (if (re-search-backward ";" nil t) (match-end 0) (point-min)))))
         (buffer-substring-no-properties beg end))))))

;;;###autoload
(defun +pg/run-sql ()
  "Ausgewaehltes SQL (Region oder Statement am Punkt) auf einem DB-Profil ausfuehren.
Fragt nach der DB (`+pg-profiles') und zeigt das Ergebnis als pgmacs-Tabelle plus
eine IntelliJ-artige Statuszeile (\"N rows affected in X ms\"). Mehrere `;'-getrennte
Statements: Region markieren; angezeigt wird das Ergebnis des letzten Statements."
  (interactive)
  (require 'pgmacs)
  (let ((sql (+pg--sql-at-point)))
    (when (string-empty-p sql)
      (user-error "Kein SQL ausgewaehlt -- Region markieren oder Cursor ins Statement setzen"))
    (let* ((label (completing-read "Auf welcher DB ausfuehren? "
                                   (mapcar #'car +pg-profiles) nil t nil nil
                                   +pg--last-profile))
           (conn  (cdr (assoc label +pg-profiles)))
           (con   (+pg--connect conn))
           (start (current-time))
           (res   (pg-exec con sql))
           (ms    (round (* 1000 (float-time (time-subtract (current-time) start))))))
      (setq +pg--last-profile label)
      (+pg--show-result con sql res ms label))))

(defun +pg--rows-phrase (status rows)
  "IntelliJ-artige Mengenangabe aus dem STATUS-Tag (z.B. \"INSERT 0 1\") und ROWS (SELECT)."
  (cond
   ((string-prefix-p "SELECT" status)
    (format "%d row%s" rows (if (= rows 1) "" "s")))
   ((string-match "\\`\\(?:INSERT\\|UPDATE\\|DELETE\\|MERGE\\)" status)
    (let ((n (if (string-match "\\([0-9]+\\)[ ]*\\'" status)
                 (string-to-number (match-string 1 status))
               rows)))
      (format "%d row%s affected" n (if (= n 1) "" "s"))))
   (t status)))

(defun +pg--show-result (con sql res ms label)
  "Bereits ausgefuehrtes RES als pgmacs-Tabelle zeigen, mit IntelliJ-artiger Statuszeile.
MS = Laufzeit in Millisekunden, LABEL = DB-Profilname. Fuehrt SQL NICHT erneut aus."
  (let ((db-buffer (bound-and-true-p pgmacs--db-buffer)))
    (pop-to-buffer (get-buffer-create "*PostgreSQL TMP*"))
    (kill-all-local-variables)
    (buffer-disable-undo)
    (setq-local pgmacs--con con
                pgmacs--db-buffer db-buffer
                buffer-read-only t
                truncate-lines t))
  (pgmacs-mode)
  (let* ((inhibit-read-only t)
         (status (or (pg-result res :status) "OK"))
         (rows   (length (pg-result res :tuples)))
         (phrase (+pg--rows-phrase status rows)))
    (erase-buffer)
    (remove-overlays)
    (insert (propertize "PostgreSQL query output" 'face 'bold) "\n")
    (insert (propertize (format "[%s] %s  |  %s in %d ms  |  DB: %s\n\n"
                                (format-time-string "%Y-%m-%d %H:%M:%S")
                                status phrase ms label)
                        'face 'success))
    (insert (propertize "SQL" 'face 'bold) (format ": %s\n\n" sql))
    (message "%s in %d ms  (%s)" phrase ms label))
  (pgmacs--show-pgresult (current-buffer) res)
  (shrink-window-if-larger-than-buffer))

;; Shortcut in .sql-Dateien: SPC m e (localleader "execute") + C-c C-c (schnell).
(after! sql
  (map! :map sql-mode-map
        :localleader
        :desc "SQL ausfuehren (DB waehlen)" "s" #'+pg/run-sql)
  (map! :map sql-mode-map "C-c C-c" #'+pg/run-sql))

;; In der pgmacs-Tabellenliste zusaetzlich `s' und `/' als Aliase fuer die
;; Tabellensuche (`pgmacs-open-table\=', Standard ist `o') -- intuitiver zum "Suchen".
;;; --------------------------------------------------------------------------
;;; Projektweite Methodensuche -- OPTIK wie `SPC SPC' / `SPC f d'
;;; --------------------------------------------------------------------------
;; Bewusst NICHT ueber `consult-lsp-symbols' (das ist async, gruppiert, braucht
;; Tippen und sieht anders aus). Stattdessen wie der Datei-Picker: EINMAL vorab
;; per ripgrep ALLE Methoden-Deklarationen (Java + Kotlin) im Projekt sammeln und
;; als flache, sofort filterbare `completing-read'-Liste (Vertico) zeigen -- mit
;; Methoden-Icon vorne, exakt die Optik von Find-File/Find-Dir. Auswahl springt
;; an Datei:Zeile. Funktioniert aus JEDEM Buffer (kein LSP noetig), da nur rg.

(defvar +find--method-java-re
  "(?:public|protected|private|static|final|abstract|synchronized|native|default)[[:space:]][^;{}()=]*[[:space:]][A-Za-z_][A-Za-z0-9_]*[[:space:]]*\\([^;{}]*\\)[[:space:]]*(?:throws[^{;]*)?\\{"
  "ripgrep-Muster (Rust-Regex) fuer Java-Methoden-/Konstruktor-Deklarationen.")

(defvar +find--method-kotlin-re
  "\\bfun[[:space:]]+(?:<[^>]+>[[:space:]]*)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\\("
  "ripgrep-Muster (Rust-Regex) fuer Kotlin-`fun'-Deklarationen.")

(defun +find--project-method-cands ()
  "Alle Java/Kotlin-Methoden im Projekt via rg sammeln.
Rueckgabe: (CANDS . TBL) -- CANDS = Liste der Anzeige-Strings (Icon + Name +
relativer Pfad:Zeile), TBL = Hash Anzeige-String -> (absolute-datei . zeile)."
  (let* ((root (or (doom-project-root) default-directory))
         (default-directory root)
         (rg   (or (executable-find "rg") (user-error "ripgrep (rg) nicht gefunden")))
         (icon (if (fboundp 'nerd-icons-codicon)
                   (concat (nerd-icons-codicon "nf-cod-symbol_method"
                                               :face 'nerd-icons-lpurple)
                           " ")
                 ""))
         (out  (with-temp-buffer
                 (call-process rg nil t nil
                               "--vimgrep" "--no-heading" "--color=never"
                               "-t" "java" "-t" "kotlin"
                               "-e" +find--method-java-re
                               "-e" +find--method-kotlin-re
                               ".")
                 (buffer-string)))
         (tbl  (make-hash-table :test 'equal))
         (skip '("if" "for" "while" "switch" "catch" "synchronized"
                 "return" "new" "else" "do" "try"))
         cands)
    (dolist (ln (split-string out "\n" t))
      ;; vimgrep-Zeile: datei:zeile:spalte:text
      (when (string-match "\\`\\(.+?\\):\\([0-9]+\\):[0-9]+:\\(.*\\)\\'" ln)
        (let* ((file (match-string 1 ln))
               (lno  (string-to-number (match-string 2 ln)))
               (text (match-string 3 ln))
               ;; Namen aus dem Deklarations-Text ziehen: erst Kotlin-`fun NAME',
               ;; sonst der Bezeichner direkt vor der ersten `(' (= Methodenname).
               (name (cond
                      ((string-match "\\bfun[ \t]+\\(?:<[^>]+>[ \t]*\\)?\\([A-Za-z_][A-Za-z0-9_]*\\)" text)
                       (match-string 1 text))
                      ((string-match "\\([A-Za-z_][A-Za-z0-9_]*\\)[ \t]*(" text)
                       (match-string 1 text)))))
          (when (and name (not (member name skip)))
            (let ((disp (format "%s%s  %s:%d"
                                icon name (file-relative-name file root) lno)))
              ;; Bei Duplikaten (gleicher Name+Ort) einfach ueberschreiben.
              (unless (gethash disp tbl)
                (push disp cands))
              (puthash disp (cons (expand-file-name file root) lno) tbl))))))
    (cons (nreverse cands) tbl)))

;;;###autoload
(defun +find/project-method ()
  "Projektweite Methodensuche mit der Optik von `SPC SPC' / `SPC f d'.
Sammelt einmalig per ripgrep alle Java/Kotlin-Methoden im Projekt und zeigt sie
als flache, sofort filterbare Liste (Vertico, mit Methoden-Icon). Auswahl springt
an Datei:Zeile. Aus JEDEM Buffer nutzbar (kein LSP noetig)."
  (interactive)
  (let* ((data  (+find--project-method-cands))
         (cands (car data))
         (tbl   (cdr data)))
    (unless cands (user-error "Keine Methoden im Projekt gefunden"))
    (let* ((choice (completing-read "Methode: " cands nil t))
           (loc    (gethash choice tbl)))
      (when loc
        (find-file (car loc))
        (goto-char (point-min))
        (forward-line (1- (cdr loc)))
        (back-to-indentation)
        (recenter)))))

(after! pgmacs
  ;; WICHTIG (Performance beim Oeffnen): pgmacs schaetzt die Zeilenzahl pro Tabelle
  ;; nur dann schnell (ueber `reltuples' aus dem Katalog, kein Table-Scan), wenn die
  ;; DB GROESSER als `pgmacs-large-database-threshold' ist. Sonst feuert es beim
  ;; Oeffnen ein teures `COUNT(*)' auf JEDE Tabelle -- bei der Entscheidungen-DB
  ;; (~41 MB, 334 Tabellen) waren das 334 Einzel-Scans nacheinander -> minutenlanger
  ;; "Hang", bis Emacs hart geschlossen werden musste. Schwelle = 0 -> IMMER der
  ;; schnelle Schaetz-Pfad -> Tabellenliste erscheint sofort.
  ;; Nachteil: bei nie `ANALYZE'-ten Tabellen ist die Schaetzung ungenau (ggf. -1);
  ;; fuer echte Zahlen einmalig in der DB `ANALYZE;' ausfuehren.
  (setq pgmacs-large-database-threshold 0)
  ;; WICHTIG (Deadlock/Freeze): pgmacs' Worker-Thread und der Main-Thread teilen sich
  ;; DIESELBE pg.el-Verbindung. Bei vielen Tabellen (hier 334) verklemmen sie sich auf
  ;; dem Socket -> `pgmacs-open' friert Emacs KOMPLETT ein (with-timeout greift nicht,
  ;; man muss hart schliessen). Verbinden + Tabellenliste selbst sind blitzschnell
  ;; (0.26s / 0.01s), nur das threaded Metadaten-Laden deadlockt. Darum Worker-Thread
  ;; aus -> alle Abfragen laufen sequentiell im Main-Thread (bei lokaler DB schnell).
  (setq pgmacs-use-worker-thread nil)
  (when (boundp 'pgmacs-table-list-map)
    (keymap-set pgmacs-table-list-map "s" #'pgmacs-open-table)
    (keymap-set pgmacs-table-list-map "/" #'pgmacs-open-table))
  ;; --- vim-artige hjkl-Navigation in den pgmacs-Tabellen -------------------
  ;; Die pgmacs-Buffer laufen im emacs-state (darum greifen Evils hjkl NICHT),
  ;; und pgmacs belegt h/j/k selbst (h=Hilfe, j=JSON, k=Kopieren; l ist frei).
  ;; Wir legen Bewegung auf hjkl und schieben die bisherigen Befehle auf GROSS:
  ;;   h = Spalte links | l = Spalte rechts | j = Zeile runter | k = Zeile hoch
  ;;   J = Zeile als JSON (war j) | K = Zeile kopieren (war k) | Hilfe bleibt `?'
  (let ((left  (if (fboundp 'pgmacstbl-previous-column) #'pgmacstbl-previous-column #'backward-char))
        (right (if (fboundp 'pgmacs--next-item) #'pgmacs--next-item #'forward-char)))
    (dolist (m (list (and (boundp 'pgmacs-row-list-map/table)   pgmacs-row-list-map/table)
                     (and (boundp 'pgmacs-row-list-map)         pgmacs-row-list-map)
                     (and (boundp 'pgmacs-table-list-map/table) pgmacs-table-list-map/table)
                     (and (boundp 'pgmacs-table-list-map)       pgmacs-table-list-map)))
      (when (keymapp m)
        (keymap-set m "j" #'next-line)
        (keymap-set m "k" #'previous-line)
        (keymap-set m "h" left)
        (keymap-set m "l" right))))
  ;; verdraengte Row-Befehle auf Grossbuchstaben retten:
  (when (boundp 'pgmacs-row-list-map/table)
    (keymap-set pgmacs-row-list-map/table "J" #'pgmacs--row-as-json)
    (keymap-set pgmacs-row-list-map/table "K" #'pgmacs--copy-row))
  ;; e / b als vim-Wortbewegungen: e = Wortende vor (war `pgmacs-run-sql' -> jetzt
  ;; auf `Q' fuer "Query"), b = Wortanfang zurueck (war unbelegt). `w' bleibt bewusst
  ;; = Wert editieren (pgmacs), daher nur e und b (kein w).
  (let ((wend  (if (fboundp 'evil-forward-word-end)   #'evil-forward-word-end   #'forward-word))
        (wback (if (fboundp 'evil-backward-word-begin) #'evil-backward-word-begin #'backward-word)))
    (dolist (m (list (and (boundp 'pgmacs-row-list-map/table)   pgmacs-row-list-map/table)
                     (and (boundp 'pgmacs-row-list-map)         pgmacs-row-list-map)
                     (and (boundp 'pgmacs-table-list-map/table) pgmacs-table-list-map/table)
                     (and (boundp 'pgmacs-table-list-map)       pgmacs-table-list-map)
                     (and (boundp 'pgmacs-transient-map)        pgmacs-transient-map)))
      (when (keymapp m)
        (keymap-set m "e" wend)
        (keymap-set m "b" wback)
        (keymap-set m "Q" #'pgmacs-run-sql))))   ; SQL interaktiv ausfuehren (war `e')
  ;; --- harmlose Warnung unterdruecken (nur Popup, bleibt im *Warnings*-Log) --
  ;; "Expected function pgmacs--paginated-next/-prev to be bound": die Tasten n/p
  ;; sind NUR bei paginierten Tabellen (>200 Zeilen) gebunden; pgmacs' Hilfe-
  ;; Generator warnt sonst -- rein kosmetisch, kein echter Fehler.
  (add-to-list 'warning-suppress-types '(pgmacs)))


;;; --------------------------------------------------------------------------
;;; 7. Profiler: async-profiler -> Flamegraph (Memory & Methodenlaufzeiten)
;;; --------------------------------------------------------------------------

(defun +jvm--pick-pid ()                                 ; laufende JVM auswaehlen (wie IntelliJ "Attach")
  (let* ((lines (split-string (shell-command-to-string "jps -l") "\n" t))
         (pick  (completing-read "JVM: " lines nil t)))
    (car (split-string pick))))

(defun +profiler--run (event)
  "async-profiler an eine laufende JVM haengen und das Ergebnis als Flamegraph zeigen.
EVENT ist z.B. \"cpu\" (Methodenlaufzeit) oder \"alloc\" (Memory/Allokation)."
  (let* ((pid (+jvm--pick-pid))
         (secs (read-number "Dauer in Sekunden: " 30))
         (out (make-temp-file "asprof-" nil ".collapsed"))
         (cmd (format "asprof -d %d -e %s -o collapsed -f %s %s"
                      secs event (shell-quote-argument out) pid)))
    (message "Profiler laeuft %ds (%s) an PID %s ..." secs event pid)
    (set-process-sentinel
     (start-process-shell-command "asprof" "*asprof*" cmd)
     (lambda (_proc ev)
       (if (string-match-p "finished" ev)
           (flamegraph-find-profile out)                 ; interaktiver Flamegraph-Buffer
         (message "async-profiler: %s" (string-trim ev)))))))

;;;###autoload
(defun +profiler/cpu () "CPU-/Methodenlaufzeit-Profil." (interactive) (+profiler--run "cpu"))
;;;###autoload
(defun +profiler/alloc () "Memory-/Allokations-Profil." (interactive) (+profiler--run "alloc"))


;;; --------------------------------------------------------------------------
;;; 8. Keybindings
;;; --------------------------------------------------------------------------

;; Java-Localleader (SPC m). Wichtig: Mit (java +tree-sitter) remappt Doom java-mode
;; auf java-ts-mode -- darum die Bindings in BEIDE Keymaps legen (sonst "SPC m undefined").
(defmacro +java-bind-localleader! (keymap)
  "Legt den Java-Localleader (SPC m ...) in KEYMAP an."
  `(progn
     ;; IntelliJ-aehnliche Methodennavigation direkt im Java-Buffer:
     (map! :map ,keymap
           :nvi "M-<up>"   #'+java/previous-method
           :nvi "M-<down>" #'+java/next-method)
     (map! :map ,keymap
           :localleader
           :desc "Maven-Menue"             "m" #'+mvn/menu                       ; mvn compile/install/deploy ...
           :desc "Rebuild Project"         "b" #'+mvn/rebuild-project           ; IntelliJ "Rebuild Project"
           :desc "Projekt pruefen (Fehler)" "c" #'+java/check-project           ; IntelliJ "Build Project": alle Fehler projektweit
           :desc "Maven-Goal (frei)"       "t" #'+mvn/execute-goal              ; IntelliJ "Execute Maven Goal"
           :desc "Run-Config (Run/Debug)"  "r" #'+idea/run                       ; Picker (dap-java)
           :desc "Run-Config (mvn exec)"   "R" #'+idea/run-mvn                   ; Picker (Fallback, Jetty)
           :desc "Run stoppen"             "k" #'+idea/stop-run                  ; dap-Session/Compilation beenden
           :desc "Rerun (letzter Lauf)"    "e" #'+idea/rerun                     ; erneut starten (stop+start)
           :desc "Debugger attach :5005"   "a" #'+idea/attach                    ; an laufende JVM andocken
           :desc "HotSwap (Klassen laden)" "h" #'+java/hotswap                   ; IntelliJ HotSwap, ohne Rebuild/Neustart
           :desc "Interface <-> Impl"      "I" #'+java/toggle-impl               ; Service <-> ServiceImpl (Datei)
           :desc "Super-Methode (Interface)" "i" #'lsp-java-open-super-implementation ; Impl-Methode -> Interface/Super-Methode (IntelliJ "Go to Super Method")
           :desc "Format (JDT/IntelliJ)"   "=" #'lsp-format-buffer               ; Formatierung nach Profil
           :desc "Imports ordnen"          "o" #'lsp-java-organize-imports
           :desc "Maven neu importieren"   "u" #'lsp-java-update-project-configuration
           :desc "Generated Sources -> Classpath" "G" #'+java/ensure-generated-source-roots
           :desc "Code-Lens an/aus"        "l" #'lsp-lens-mode                   ; Referenz-Zaehler bei Bedarf
           :desc "LSP neu verbinden"       "L" #'+java/lsp-reconnect             ; Reparatur: lsp im Buffer (neu) starten, wenn Vorschlaege fehlen
           ;; Tests jetzt unter "T" (Shift-t), da "t" das freie Maven-Goal ist:
           (:prefix ("T" . "Test")
            :desc "Test (Klasse/Methode)" "t" #'+java/run-test
            :desc "Alle Tests der Klasse" "a" #'dap-java-run-test-class
            :desc "Test debuggen"         "d" #'+java/debug-test
            :desc "Alle Tests debuggen"   "D" #'dap-java-debug-test-class)
           ;; Override/Implement & Code-Generierung (IntelliJ "Override Methods"/"Generate"):
           (:prefix ("g" . "generieren")
            :desc "Override/Implement Methods" "o" #'lsp-java-generate-overrides ; Mehrfach-Auswahl
            :desc "Getter & Setter"            "g" #'lsp-java-generate-getters-and-setters
            :desc "toString()"                 "s" #'lsp-java-generate-to-string
            :desc "equals() & hashCode()"      "e" #'lsp-java-generate-equals-and-hash-code)
           ;; Profiler (async-profiler -> Flamegraph):
           (:prefix ("P" . "Profiler")
            :desc "CPU/Methodenlaufzeit" "c" #'+profiler/cpu
            :desc "Memory/Allokation"    "m" #'+profiler/alloc))))

(after! cc-mode      (+java-bind-localleader! java-mode-map))     ; Fallback (Grammar fehlt)
(after! java-ts-mode (+java-bind-localleader! java-ts-mode-map))  ; Standard mit +tree-sitter

;; Maven-Befehle (SPC m ...) auch ausserhalb von Java-Buffern verfuegbar machen.
;; Problem: SPC m ist Doom-Localleader (modusabhaengig) und war nur in Java-Maps belegt.
;; Folge: In .properties-/pom.xml-Dateien war "SPC m undefined". Hier ein schlankes
;; Maven-Localleader-Set fuer Properties (conf-*-mode) und XML/pom (nxml-mode).
(defmacro +mvn-bind-localleader! (keymap)
  "Legt ein schlankes Maven-Localleader-Set (SPC m ...) in KEYMAP an."
  `(map! :map ,keymap
         :localleader
         :desc "Maven-Menue"           "m" #'+mvn/menu
         :desc "Rebuild Project"       "b" #'+mvn/rebuild-project
         :desc "Maven-Goal (frei)"     "t" #'+mvn/execute-goal
         :desc "Maven neu importieren" "u" #'lsp-java-update-project-configuration))

(after! conf-mode
  (+mvn-bind-localleader! conf-mode-map)            ; *.conf u.ae.
  (when (boundp 'conf-javaprop-mode-map)
    (+mvn-bind-localleader! conf-javaprop-mode-map))) ; *.properties
(after! nxml-mode (+mvn-bind-localleader! nxml-mode-map))  ; pom.xml / *.xml

;; Globale Schnellzugriffe (wie ein "Run"-/"Stop"-Button bzw. DB-Tool). Global,
;; damit "Run stoppen" auch im Ausgabe-Fenster (dap-out/*compilation*) greift, wo
;; der Java-Localleader nicht gilt.
(map! :leader
      :desc "Run-Config starten" "r r" #'+idea/run                            ; Run/Debug-Picker
      :desc "Run stoppen"        "r k" #'+idea/stop-run                        ; dap-Session/Compilation beenden
      :desc "Rerun (letzter Lauf)" "r e" #'+idea/rerun                          ; erneut starten (stop+start)
      :desc "HotSwap (Klassen laden)" "r h" #'+java/hotswap                       ; IntelliJ HotSwap (Debug)
      :desc "DB: Postgres oeffnen (C-u = Tabellensuche)" "o d" #'+pg/open)    ; pgmacs-Profil-Picker; C-u SPC o d -> direkt Tabellensuche

(provide '+java)
;;; +java.el ends here


;;; --------------------------------------------------------------------------
;;; IntelliJ-artiges "New ..." -- Klasse/Interface/Enum/Record/... anlegen
;;; --------------------------------------------------------------------------
;; Wie IntelliJs "New" (Alt+Einfg): Typ auswaehlen -> Datei mit passendem Template
;; anlegen. Das Paket wird aus dem Pfad (src/main|test/java|kotlin/...) abgeleitet.
;; Beim Namen darf ein RELATIVES Unterpaket mitgegeben werden (z.B. "sub.paket.Name"),
;; dann werden die Unterordner miterzeugt. Aufruf global via `SPC c n' oder im
;; Projektbaum (Treemacs, `SPC o p'): Taste `N' bzw. `c j' -> legt im ausgewaehlten
;; Verzeichnis an und oeffnet die Datei im Editorfenster.

(defvar +java-new-templates
  '(("Java-Klasse"      :ext "java" :body "public class %s {\n\n}\n")
    ("Java-Interface"   :ext "java" :body "public interface %s {\n\n}\n")
    ("Java-Enum"        :ext "java" :body "public enum %s {\n\n}\n")
    ("Java-Record"      :ext "java" :body "public record %s() {\n\n}\n")
    ("Java-Annotation"  :ext "java" :body "public @interface %s {\n\n}\n")
    ("Kotlin-Klasse"     :ext "kt" :body "class %s {\n\n}\n"     :kotlin t)
    ("Kotlin-Data-Class" :ext "kt" :body "data class %s(\n\n)\n" :kotlin t)
    ("Kotlin-Interface"  :ext "kt" :body "interface %s {\n\n}\n" :kotlin t)
    ("Kotlin-Object"     :ext "kt" :body "object %s {\n\n}\n"    :kotlin t)
    ("Kotlin-Enum"       :ext "kt" :body "enum class %s {\n\n}\n" :kotlin t))
  "IntelliJ-artige `New'-Vorlagen: Label -> Plist (:ext EXT :body FORMAT [:kotlin t]).
BODY ist ein `format'-String mit genau einem %s fuer den Typnamen.")

(defun +java--package-for-dir (dir)
  "Java/Kotlin-Paketname fuer DIR aus dem Pfad ableiten (nach src/main|test/java|kotlin).
nil (= Default-Paket), wenn DIR genau die Source-Root ist oder nichts passt."
  (let ((d (directory-file-name (expand-file-name dir))))
    (when (string-match "/src/\\(?:main\\|test\\)/\\(?:java\\|kotlin\\)/\\(.+\\)\\'" d)
      (replace-regexp-in-string "/" "." (match-string 1 d)))))

(defun +java--new-target-dir ()
  "Zielverzeichnis fuer eine neue Datei: im Treemacs der Knoten, sonst Buffer-Verzeichnis."
  (or (and (derived-mode-p 'treemacs-mode)
           (let ((path (or (ignore-errors (treemacs--prop-at-point :path))
                           (ignore-errors (treemacs-button-get (treemacs-current-button) :path)))))
             (cond ((and (stringp path) (file-directory-p path)) path)
                   ((and (stringp path) (file-exists-p path)) (file-name-directory path)))))
      (and buffer-file-name (file-name-directory buffer-file-name))
      default-directory))

;;;###autoload
(defun +java/new-type (&optional dir)
  "IntelliJ-artiges \"New\": Typ (Klasse/Interface/Enum/...) waehlen und Datei anlegen.
DIR = Zielverzeichnis (Default: Treemacs-Knoten bzw. aktuelles Buffer-Verzeichnis).
Beim Namen darf ein relatives Unterpaket mitgegeben werden (z.B. `sub.Paket.Name')."
  (interactive)
  (let* ((from-tree (derived-mode-p 'treemacs-mode))
         (dir    (or dir (+java--new-target-dir)))
         (label  (completing-read "Neu (IntelliJ): "
                                  (mapcar #'car +java-new-templates) nil t))
         (tpl    (cdr (assoc label +java-new-templates)))
         (ext    (plist-get tpl :ext))
         (kotlin (plist-get tpl :kotlin))
         (raw    (string-trim (read-string (format "%s -- Name (ggf. paket.Name): " label))))
         (raw    (replace-regexp-in-string (format "\\.%s\\'" ext) "" raw)))
    (when (string-empty-p raw) (user-error "Kein Name angegeben"))
    (let* ((parts    (split-string raw "\\." t))
           (name     (car (last parts)))
           (sub      (butlast parts))
           (base-pkg (+java--package-for-dir dir))
           (full-pkg (string-join (append (and base-pkg (split-string base-pkg "\\." t)) sub) "."))
           (target-d (expand-file-name (string-join sub "/") dir))
           (file     (expand-file-name (concat name "." ext) target-d)))
      (unless (string-match-p "\\`[A-Za-z_][A-Za-z0-9_]*\\'" name)
        (user-error "Ungueltiger Typname: %s" name))
      (when (file-exists-p file)
        (user-error "Datei existiert bereits: %s" file))
      (make-directory target-d t)
      (with-temp-file file
        (when (and full-pkg (not (string-empty-p full-pkg)))
          (insert (format (if kotlin "package %s\n\n" "package %s;\n\n") full-pkg)))
        (insert (format (plist-get tpl :body) name)))
      ;; Datei im Editorfenster oeffnen (aus dem schmalen Treemacs-Fenster heraus
      ;; das zuletzt benutzte andere Fenster waehlen), nicht im Baum-Fenster:
      (let ((buf (find-file-noselect file)))
        (when from-tree
          (select-window (or (get-mru-window nil nil t) (next-window))))
        (switch-to-buffer buf))
      ;; Cursor in den leeren Rumpf (nach der ersten offenen { bzw. () setzen:
      (goto-char (point-min))
      (when (re-search-forward "[{(]\n" nil t)
        (when (bound-and-true-p evil-local-mode) (evil-insert-state)))
      ;; Treemacs (falls sichtbar) auffrischen, damit die neue Datei erscheint:
      (when (and (fboundp 'treemacs-current-visibility)
                 (eq (treemacs-current-visibility) 'visible))
        (ignore-errors (treemacs-refresh)))
      (message "Angelegt: %s (Paket: %s)" (file-name-nondirectory file)
               (if (string-empty-p full-pkg) "<default>" full-pkg)))))

;; --- Keybindings: global + Treemacs -------------------------------------------
(map! :leader :desc "Neu: Klasse/Interface/Enum ..." "c n" #'+java/new-type)

(after! treemacs
  ;; `N' als schneller Zugriff, zusaetzlich `c j' unter dem vorhandenen
  ;; Treemacs-Create-Prefix (dort sind schon `c f'=Datei, `c d'=Verzeichnis).
  (define-key treemacs-mode-map (kbd "N")   #'+java/new-type)
  (define-key treemacs-mode-map (kbd "c j") #'+java/new-type))


;;; --------------------------------------------------------------------------
;;; Warnung: lokale Variable/Parameter koennte `final' sein (tree-sitter, JVM-frei)
;;; --------------------------------------------------------------------------
;; IntelliJs Inspection "can be final" gibt es in JDT.LS nicht. Statt eines externen
;; Tools (checkstyle -> JVM pro Save) nutzen wir die vorhandene tree-sitter-Java-
;; Grammatik: wir durchsuchen den Parse-Baum nach formal_parameter / local_variable_
;; declaration / catch_formal_parameter OHNE `final'-Modifier und melden das als
;; flycheck-Warnung. Laeuft komplett in Emacs (kein externer Prozess), auch in
;; java-mode (Parser wird bei Bedarf angelegt) und java-ts-mode.

(defvar +java-final-enable t
  "Wenn non-nil, warnt der tree-sitter-Checker vor fehlendem `final'.")

(defvar +java-final-level 'warning
  "flycheck-Level fuer die Meldung: `warning' (gelb) oder `info' (dezent, wie IntelliJ-Weak).")

(defvar +java-final--query
  "(formal_parameter) @p (local_variable_declaration) @l (catch_formal_parameter) @c"
  "tree-sitter-Query: Parameter, lokale Variablen und catch-Parameter.")

(defun +java-final--root ()
  "Wurzelknoten eines Java-Parsers fuer den aktuellen Buffer (bei Bedarf anlegen)."
  (when (and (fboundp 'treesit-available-p) (treesit-available-p)
             (ignore-errors (treesit-ready-p 'java t)))
    (let ((parser (or (car (treesit-parser-list nil 'java))
                      (ignore-errors (treesit-parser-create 'java)))))
      (and parser (treesit-parser-root-node parser)))))

(defun +java-final--has-final (node)
  "Hat NODE einen `modifiers'-Kindknoten, der `final' enthaelt?"
  (let ((n (treesit-node-child-count node)) (found nil) (i 0))
    (while (and (< i n) (not found))
      (let ((c (treesit-node-child node i)))
        (when (and (string= (treesit-node-type c) "modifiers")
                   (string-match-p "\\_<final\\_>" (treesit-node-text c t)))
          (setq found t)))
      (setq i (1+ i)))
    found))

(defun +java-final--name (node)
  "Deklarierter Name aus NODE (Parameter direkt, lokale Variable ueber declarator)."
  (or (let ((nm (treesit-node-child-by-field-name node "name")))
        (and nm (treesit-node-text nm t)))
      (let ((d (treesit-node-child-by-field-name node "declarator")))
        (and d (let ((nm (treesit-node-child-by-field-name d "name")))
                 (and nm (treesit-node-text nm t)))))))

(defun +java-final--scope (node)
  "Umschliessender Methoden-/Konstruktor-/Lambda-/Initializer-Knoten von NODE.
Fallback: Elternknoten bzw. NODE selbst."
  (or (treesit-parent-until
       node
       (lambda (p) (member (treesit-node-type p)
                           '("method_declaration" "constructor_declaration"
                             "compact_constructor_declaration"
                             "static_initializer" "lambda_expression"))))
      (treesit-node-parent node)
      node))

(defvar +java-final--assign-query
  "(assignment_expression left: (identifier) @a) (update_expression (identifier) @u)"
  "tree-sitter-Query: Zuweisungsziele (=, +=, ...) sowie ++/-- .")

(defun +java-final--reassigned-names (scope)
  "Hash-Set der Namen, die in SCOPE spaeter neu zugewiesen werden (=, +=, ++, --).
Solche Variablen/Parameter koennen NICHT `final' sein und werden nicht gemeldet.
Feld-/Array-Zuweisungen (this.x=, arr[i]=) zaehlen bewusst NICHT (kein `identifier'-Ziel)."
  (let ((tbl (make-hash-table :test 'equal)))
    (dolist (cap (treesit-query-capture scope +java-final--assign-query))
      (puthash (treesit-node-text (cdr cap) t) t tbl))
    tbl))

(defun +java-final--collect (checker)
  "Liste von flycheck-Fehlern fuer Deklarationen ohne `final' im aktuellen Buffer.
Variablen/Parameter, die im umschliessenden Scope spaeter neu zugewiesen werden,
werden uebersprungen (sie koennen ja nicht `final' sein)."
  (let ((root (+java-final--root)) errors (cache (make-hash-table :test 'eql)))
    (when root
      (dolist (cap (treesit-query-capture root +java-final--query))
        (let ((node (cdr cap)))
          (unless (+java-final--has-final node)
            (let* ((name  (+java-final--name node))
                   (scope (+java-final--scope node))
                   (skey  (treesit-node-start scope))
                   (reassigned (or (gethash skey cache)
                                   (puthash skey (+java-final--reassigned-names scope) cache))))
              (unless (and name (gethash name reassigned))
                (let* ((pos  (treesit-node-start node))
                       (line (line-number-at-pos pos))
                       (col  (save-excursion (goto-char pos) (1+ (current-column))))
                       (kind (pcase (treesit-node-type node)
                               ("formal_parameter"       "Parameter")
                               ("catch_formal_parameter" "catch-Parameter")
                               (_                        "Lokale Variable"))))
                  (push (flycheck-error-new-at
                         line col +java-final-level
                         (format "%s%s koennte 'final' sein" kind
                                 (if name (format " '%s'" name) ""))
                         :checker checker)
                        errors))))))))
    (nreverse errors)))

(defun +java-final--start (checker callback)
  "flycheck-Generic-Checker-Start: sammelt Meldungen synchron (schnell, in-process)."
  (condition-case err
      (funcall callback 'finished (+java-final--collect checker))
    (error (funcall callback 'errored (error-message-string err)))))

(with-eval-after-load 'flycheck
  (flycheck-define-generic-checker 'java-final-ts
    "Warnt vor lokalen Variablen/Parametern ohne `final' (tree-sitter, JVM-frei)."
    :start #'+java-final--start
    :modes '(java-mode java-ts-mode)
    :predicate (lambda () +java-final-enable))
  (add-to-list 'flycheck-checkers 'java-final-ts)
  ;; NACH dem lsp-Checker laufen lassen (lsp bleibt Haupt-Diagnose):
  (with-eval-after-load 'lsp-mode
    (unless (and (fboundp 'flycheck-get-next-checkers)
                 (memq 'java-final-ts (ignore-errors (flycheck-get-next-checkers 'lsp))))
      (ignore-errors (flycheck-add-next-checker 'lsp 'java-final-ts 'append)))))

;;;###autoload
(defun +java/toggle-final-warnings ()
  "final-Warnungen an/aus schalten (danach flycheck im Buffer neu pruefen).
Alternativ dauerhaft: `+java-final-enable' nil setzen, oder `+java-final-level'
auf `info' fuer die dezente (IntelliJ-Weak-Warning-artige) Darstellung."
  (interactive)
  (setq +java-final-enable (not +java-final-enable))
  (when (bound-and-true-p flycheck-mode) (flycheck-buffer))
  (message "final-Warnungen: %s" (if +java-final-enable "AN" "AUS")))

;;; --------------------------------------------------------------------------
;;; Methodensuche inkl. Dependencies (Quellprojekte)  --  SPC f M
;;; --------------------------------------------------------------------------
;; Wie `+find/project-method' (SPC f m, gleiche flache Vertico-Optik mit Methoden-
;; Icon), aber ripgrep laeuft ueber das Projekt UND alle weiteren Quellprojekte, die
;; JDT.LS im Workspace geladen hat (= die Dependency-Quellprojekte auf der Platte,
;; z.B. service-framework-core). Reine Binaer-JARs ohne Quellen sind nicht enthalten
;; (JDT.LS indexiert dafuer keine Methoden -- fuer Library-TYPEN gibt es `SPC s a').
;; Der Anzeige-Pfad wird mit dem Projektnamen praefixiert (welches Projekt der Treffer).

(defun +find--parse-methods (root out icon skip tbl)
  "vimgrep-OUT aus ROOT parsen, Treffer in TBL eintragen; Liste der Anzeige-Strings.
Jeder Eintrag: Icon + Methodenname + `Projektname/relativer-Pfad:Zeile'."
  (let ((rootname (file-name-nondirectory (directory-file-name root))) cands)
    (dolist (ln (split-string out "\n" t))
      (when (string-match "\\`\\(.+?\\):\\([0-9]+\\):[0-9]+:\\(.*\\)\\'" ln)
        (let* ((file (match-string 1 ln))
               (lno  (string-to-number (match-string 2 ln)))
               (text (match-string 3 ln))
               (name (cond
                      ((string-match "\\bfun[ \t]+\\(?:<[^>]+>[ \t]*\\)?\\([A-Za-z_][A-Za-z0-9_]*\\)" text)
                       (match-string 1 text))
                      ((string-match "\\([A-Za-z_][A-Za-z0-9_]*\\)[ \t]*(" text)
                       (match-string 1 text)))))
          (when (and name (not (member name skip)))
            (let ((disp (format "%s%s  %s/%s:%d"
                                icon name rootname (file-relative-name file root) lno)))
              (unless (gethash disp tbl) (push disp cands))
              (puthash disp (cons (expand-file-name file root) lno) tbl))))))
    (nreverse cands)))

(defun +find--deps-roots ()
  "Suchwurzeln fuer die Methodensuche inkl. Dependencies:
aktuelles Projekt + alle JDT.LS-Workspace-Ordner (dedupliziert)."
  (let* ((proj  (directory-file-name (or (doom-project-root) default-directory)))
         (ws    (ignore-errors
                  (mapcar #'directory-file-name (lsp-session-folders (lsp-session)))))
         (roots (delete-dups (cons proj (copy-sequence (or ws nil))))))
    (seq-filter #'file-directory-p roots)))

(defun +find--deps-method-cands ()
  "Alle Java/Kotlin-Methoden ueber Projekt + Dependency-Quellprojekte sammeln.
Rueckgabe: (CANDS TBL . ROOTS)."
  (let* ((rg    (or (executable-find "rg") (user-error "ripgrep (rg) nicht gefunden")))
         (icon  (if (fboundp 'nerd-icons-codicon)
                    (concat (nerd-icons-codicon "nf-cod-symbol_method"
                                                :face 'nerd-icons-lpurple)
                            " ")
                  ""))
         (skip  '("if" "for" "while" "switch" "catch" "synchronized"
                  "return" "new" "else" "do" "try"))
         (roots (+find--deps-roots))
         (tbl   (make-hash-table :test 'equal))
         cands)
    (dolist (root roots)
      (let* ((default-directory root)
             (out (with-temp-buffer
                    (call-process rg nil t nil
                                  "--vimgrep" "--no-heading" "--color=never"
                                  "-t" "java" "-t" "kotlin"
                                  "-e" +find--method-java-re
                                  "-e" +find--method-kotlin-re
                                  ".")
                    (buffer-string))))
        (setq cands (nconc cands (+find--parse-methods root out icon skip tbl)))))
    (cons cands (cons tbl roots))))

;;;###autoload
(defun +find/project-method-deps ()
  "Methodensuche wie `SPC f m', aber ueber Projekt UND Dependency-Quellprojekte.
Sammelt per ripgrep alle Java/Kotlin-Methoden aus dem aktuellen Projekt und allen
weiteren JDT.LS-Workspace-Ordnern (z.B. service-framework-core) und zeigt sie als
flache, sofort filterbare Vertico-Liste (Methoden-Icon, Projektname im Pfad). Reine
Binaer-JARs ohne Quellen sind NICHT enthalten -- fuer Library-Typen: `SPC s a'."
  (interactive)
  (let* ((data  (+find--deps-method-cands))
         (cands (car data))
         (tbl   (cadr data))
         (roots (cddr data)))
    (unless cands (user-error "Keine Methoden gefunden (laeuft JDT.LS? sonst wie SPC f m)"))
    (when (= (length roots) 1)
      (message "Hinweis: nur 1 Projekt geladen -- oeffne eine Datei aus dem Dependency-Projekt, damit JDT.LS es einbezieht"))
    (let* ((choice (completing-read
                    (format "Methode (inkl. Deps, %d Projekte): " (length roots))
                    cands nil t))
           (loc    (gethash choice tbl)))
      (when loc
        (find-file (car loc))
        (goto-char (point-min))
        (forward-line (1- (cdr loc)))
        (back-to-indentation)
        (recenter)))))

;;; --------------------------------------------------------------------------
;;; JUnit-Test-Runner-Jar fuer dap-java bereitstellen  (SPC m T a / t)
;;; --------------------------------------------------------------------------
;; dap-java startet Java-Tests via `java -jar <dap-java-test-runner> -c/-m <Test>'
;; (JUnit-Platform-Console-Standalone). Diese Jar ist NICHT mit dap-java gebundelt;
;; fehlt sie, bricht der Debug-Adapter mit "Unable to access jarfile" ab (genau der
;; Fehler bei SPC m T). Wir stellen sicher, dass `dap-java-test-runner' auf eine
;; vorhandene Jar zeigt: falls die erwartete Datei fehlt, wird die neueste
;; console-standalone aus ~/.m2 (von Maven ohnehin gezogen) dorthin kopiert.
(after! dap-java
  (defun +dap-java--ensure-test-runner ()
    "Sicherstellen, dass `dap-java-test-runner' existiert (sonst aus ~/.m2 kopieren)."
    (unless (and (stringp dap-java-test-runner) (file-exists-p dap-java-test-runner))
      (let* ((m2   (expand-file-name
                    "~/.m2/repository/org/junit/platform/junit-platform-console-standalone"))
             (jars (and (file-directory-p m2)
                        (directory-files-recursively
                         m2 "junit-platform-console-standalone-.*\\.jar\\'")))
             (jar  (car (last (sort jars #'string<)))))
        (when jar
          (make-directory (file-name-directory dap-java-test-runner) t)
          (copy-file jar dap-java-test-runner t)
          (message "dap-java: Test-Runner installiert (%s)" (file-name-nondirectory jar)))))
    (and (stringp dap-java-test-runner) (file-exists-p dap-java-test-runner)))
  (+dap-java--ensure-test-runner))
