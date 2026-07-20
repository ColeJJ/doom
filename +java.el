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
        lsp-modeline-code-actions-enable nil     ; keine staendige Code-Action-Abfrage in der Modeline
        lsp-modeline-workspace-status-enable nil
        lsp-keep-workspace-alive nil             ; Server beenden, wenn letzter Java-Buffer zu ist
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

;; WICHTIG: Doom haengt den LSP-Autostart (lsp!) nur an java-mode-local-vars-hook.
;; Mit (java +tree-sitter) laufen .java-Dateien aber in java-ts-mode -> JDT.LS wuerde
;; dort NICHT automatisch starten (genau das verursacht "resolveClasspath failed" /
;; "does not support workspace/executeCommand", weil gar kein Java-Server laeuft).
(add-hook 'java-ts-mode-local-vars-hook #'lsp! 'append)

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

;; Java/Kotlin NICHT ueber apheleia formatieren (sonst Google-Style-Konflikt),
;; sondern ueber den JDT-Formatter mit deinem Profil:
(after! apheleia
  (dolist (m '(java-mode java-ts-mode kotlin-mode kotlin-ts-mode))
    (setf (alist-get m apheleia-mode-alist nil 'remove) nil)))


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
  (unless (and (fboundp 'lsp-workspaces) (lsp-workspaces))
    (user-error "Kein JDT.LS in diesem Buffer aktiv -- erst eine .java-Datei oeffnen und JDT.LS importieren lassen (Modeline/M-x lsp), oder den Jetty-Weg nehmen: SPC m R (mvn exec:java)"))
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

;;;###autoload
(defun +idea/run ()
  "IntelliJ-Run-Config auswaehlen und ueber dap-java starten (Run oder Debug)."
  (interactive)
  (let* ((pick (+idea--pick-config))
         (debug (string= "Debug" (completing-read "Aktion: " '("Run" "Debug") nil t))))
    (+idea--remember-run 'dap (car pick) (cdr pick) debug)
    (+idea--launch (car pick) (cdr pick) debug)))

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
         ('dap (+idea--launch name cfg debug))
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

(after! dap-mode
  ;; `controls' aus der Auto-Konfiguration nehmen -> nicht mehr automatisch beim
  ;; Session-Start aktiv (locals/breakpoints/expressions/tooltip bleiben erhalten):
  (setq dap-auto-configure-features
        (delq 'controls dap-auto-configure-features)))

(after! dap-ui
  (defun +dap/controls-on (&rest _)
    "Debug-Toolbar einblenden (bei Halt am Breakpoint/Step)."
    (dap-ui-controls-mode 1))
  (defun +dap/controls-off (&rest _)
    "Debug-Toolbar ausblenden (beim Weiterlaufen/Session-Ende)."
    (dap-ui-controls-mode -1))
  ;; Hooks werden mit dem debug-session-Objekt aufgerufen -> Argument ignorieren:
  (add-hook 'dap-stopped-hook    #'+dap/controls-on)   ; Breakpoint erreicht / Step fertig -> zeigen
  (add-hook 'dap-continue-hook   #'+dap/controls-off)  ; weiter laufen -> verstecken
  (add-hook 'dap-terminated-hook #'+dap/controls-off)) ; Session zu Ende -> verstecken


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
  '(("ENT - Postgres (5432)"        . "user=USER host=localhost port=5432 dbname=DBNAME")
    ("BAS - Postgres (5433)"        . "user=USER host=localhost port=5433 dbname=DBNAME")
    ("Guide-Client - magellan (5432)" . "user=sa host=localhost port=5432 dbname=magellan"))
  "Benannte Postgres-Verbindungen, analog den IntelliJ-DataSources.
USER/DBNAME bitte anpassen; Passwort kommt aus ~/.authinfo.")

;;;###autoload
(defun +pg/open ()
  "Postgres-Profil auswaehlen (wie 'find file') und in pgmacs oeffnen."
  (interactive)
  (let* ((name (completing-read "DB-Profil: " (mapcar #'car +pg-profiles) nil t))
         (conn (cdr (assoc name +pg-profiles))))
    (pgmacs-open-string conn)))


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
           :desc "Code-Lens an/aus"        "l" #'lsp-lens-mode                   ; Referenz-Zaehler bei Bedarf
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
      :desc "DB: Postgres oeffnen" "o d" #'+pg/open)                          ; pgmacs-Profil-Picker

(provide '+java)
;;; +java.el ends here
