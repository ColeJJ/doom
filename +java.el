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
  ;; Performance bei vielen Dateien; target/.idea nicht ueberwachen:
  (setq lsp-file-watch-threshold 100000
        lsp-idle-delay 0.5)
  (dolist (re '("[/\\\\]target\\'" "[/\\\\]\\.idea\\'" "[/\\\\]node_modules\\'"))
    (add-to-list 'lsp-file-watch-ignored-directories re)))

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

(defun +mvn--root ()                                     ; Reactor-Wurzel (oberstes pom.xml)
  (or (locate-dominating-file default-directory "pom.xml") (doom-project-root)))

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

(defun +idea--launch (name cfg debug)                    ; via dap-java starten (debug=nil -> reiner Run)
  (require 'dap-java)
  ;; dap-java braucht einen laufenden JDT.LS (fuer resolveClasspath/-MainClass):
  (unless (and (fboundp 'lsp-workspaces) (lsp-workspaces))
    (user-error "Kein JDT.LS in diesem Buffer aktiv -- erst eine .java-Datei oeffnen und JDT.LS importieren lassen (Modeline/M-x lsp), oder den Jetty-Weg nehmen: SPC m R (mvn exec:java)"))
  (let ((tmpl (list :type "java" :request "launch" :name name
                    :mainClass   (plist-get cfg :main)
                    :projectName (plist-get cfg :module)
                    :vmArgs      (or (plist-get cfg :vmargs) "")
                    :cwd         (+idea--expand-wd cfg)
                    :env         (plist-get cfg :envs))))   ; alist (KEY . VALUE), von dap unterstuetzt
    (dap-debug (if debug tmpl (append tmpl (list :noDebug t))))))

(defun +idea--pick-config ()                             ; Picker: Name -> Plist
  (let* ((configs (+idea-run-configs)))
    (unless configs
      (user-error "Keine Application-Run-Configs in %s.idea/runConfigurations gefunden"
                  (abbreviate-file-name (+idea--project-root))))
    (let ((name (completing-read "Run-Config: " (mapcar #'car configs) nil t)))
      (cons name (cdr (assoc name configs))))))

;;;###autoload
(defun +idea/run ()
  "IntelliJ-Run-Config auswaehlen und ueber dap-java starten (Run oder Debug)."
  (interactive)
  (let* ((pick (+idea--pick-config))
         (mode (completing-read "Aktion: " '("Run" "Debug") nil t)))
    (+idea--launch (car pick) (cdr pick) (string= mode "Debug"))))

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
         (run (format "cd %s && env %s MAVEN_OPTS=%s mvn -Pent-dev %s compile exec:java -Dexec.mainClass=%s -Dexec.classpathScope=compile"
                      (shell-quote-argument wd) envs (shell-quote-argument vm)
                      +idea--mvn-ssl-flags
                      (shell-quote-argument (plist-get cfg :main)))))
    (concat build run)))

;;;###autoload
(defun +idea/run-mvn ()
  "Run-Config ueber 'mvn exec:java' starten (Fallback fuer den Jetty-Starter).
Baut bei `+idea-build-dependencies' zuerst die abhaengigen Module (mvn -am install),
damit die webapp nicht gegen veraltete ~/.m2-JARs kompiliert.
Bei Debug wird JDWP auf Port 5005 geoeffnet -- danach mit `+idea/attach' verbinden."
  (interactive)
  (let* ((pick (+idea--pick-config))
         (cfg  (cdr pick))
         (debug (string= "Debug" (completing-read "Aktion: " '("Run" "Debug") nil t)))
         ;; Arbeitsverzeichnis aufloesen (absolut, ~ expandiert) und pruefen:
         (default-directory (file-name-as-directory
                             (or (+idea--expand-wd cfg) (+idea--project-root)))))
    (unless (file-directory-p default-directory)
      (user-error "Arbeitsverzeichnis existiert nicht: %s" default-directory))
    (when +idea-build-dependencies
      (message "Baue zuerst abhaengige Module (mvn -am install) -- das kann beim ersten Mal dauern ..."))
    (compile (+idea--mvn-command cfg debug))
    (when debug
      (message "JDWP auf :5005 -- sobald Jetty laeuft, mit `SPC m a' (+idea/attach) verbinden."))))

(after! dap-mode
  (require 'dap-java)
  ;; "Remote JVM Debug"-Aequivalent (an laufende JVM mit JDWP :5005 andocken):
  (dap-register-debug-template
   "ENT attach :5005"
   (list :type "java" :request "attach" :hostName "localhost" :port 5005)))

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
           :desc "Debugger attach :5005"   "a" #'+idea/attach                    ; an laufende JVM andocken
           :desc "Interface <-> Impl"      "I" #'+java/toggle-impl               ; Service <-> ServiceImpl
           :desc "Format (JDT/IntelliJ)"   "=" #'lsp-format-buffer               ; Formatierung nach Profil
           :desc "Imports ordnen"          "o" #'lsp-java-organize-imports
           :desc "Maven neu importieren"   "u" #'lsp-java-update-project-configuration
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

;; Globale Schnellzugriffe (wie ein "Run"-Button bzw. DB-Tool):
(map! :leader
      :desc "Run-Config starten" "r r" #'+idea/run                            ; Run/Debug-Picker
      :desc "DB: Postgres oeffnen" "o d" #'+pg/open)                          ; pgmacs-Profil-Picker

(provide '+java)
;;; +java.el ends here
