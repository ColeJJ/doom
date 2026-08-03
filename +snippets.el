;;; +snippets.el -*- lexical-binding: t; -*-
;;
;; Portierung der IntelliJ **Live Templates** nach yasnippet (Doom-Modul
;; `:editor snippets'). Quelle: der Settings-Export aus IntelliJ, Gruppen
;;   Java (35), Liquibase (24), GC_Liquibase (12), Kotlin (1), xsl (1)  = 73 Templates.
;;
;; ABBILDUNG IntelliJ -> yasnippet
;;   $VAR$ mit alwaysStopAt=true ........ Tab-Stop `$1', `$2', ...
;;   $END$ .............................. Endposition `$0'
;;   Variable mehrfach verwendet ........ erste Stelle = Feld, weitere = Mirror
;;   className() ....................... `+snip/class-name' (tree-sitter, sonst Dateiname)
;;   decapitalize(X) ................... Mirror mit `+snip/decap'
;;   capitalize(camelCase(X)) .......... Mirror mit `+snip/capitalize-camel'
;;   groovyScript("UUID.randomUUID()") . `+snip/uuid'
;;   RandomStringUtils.random(22,...) .. `+snip/fk-suffix' / `+snip/fk-name'
;;   Context (JAVA_DECLARATION etc.) ... Major-Mode der Snippet-Tabelle
;;
;; WICHTIG zu den Modes: `java-ts-mode' hat `java-mode' als Parent und
;; `kotlin-ts-mode' hat `kotlin-mode' -- yasnippet aktiviert Parent-Tabellen mit,
;; darum genuegt je EINE Definition. `nxml-mode' (Liquibase-XML) erbt von
;; `text-mode'; die beiden Templates mit IntelliJ-Context "OTHER" (`genid',
;; `sod_uuid') liegen deshalb in `text-mode' UND `prog-mode', damit sie -- wie in
;; IntelliJ -- praktisch ueberall greifen.
;;
;; ZWEI UNVERMEIDBARE UNTERSCHIEDE (yasnippet kann das nicht 1:1):
;;   1. Variablen, die IntelliJ vorbelegt UND anspringt (z.B. `momo' -> VAR =
;;      decapitalize(CLASSNAME)), werden hier zu automatisch mitlaufenden Mirrors.
;;      Sie aktualisieren sich korrekt, sind aber nicht separat editierbar.
;;   2. `toShortenFQNames="true"' (IntelliJ kuerzt FQNs und ergaenzt den Import)
;;      gibt es nicht. Templates mit FQN (`logger', `timeTravel') fuegen den
;;      vollqualifizierten Namen ein -- das kompiliert ohne Import. Verkuerzen
;;      danach per `SPC m o' (Imports ordnen).

;;; --------------------------------------------------------------------------
;;; Hilfsfunktionen -- Nachbau der IntelliJ-Ausdruecke
;;; --------------------------------------------------------------------------

(defun +snip/uuid ()
  "UUID wie IntelliJs groovyScript(\"UUID.randomUUID().toString()\").
Java liefert Kleinschreibung, macOS `uuidgen' Grossschreibung -> downcase."
  (if (executable-find "uuidgen")
      (downcase (string-trim (shell-command-to-string "uuidgen")))
    ;; Fallback ohne externes Tool: Version-4-UUID aus Zufallswerten
    (format "%04x%04x-%04x-4%03x-%x%03x-%04x%04x%04x"
            (random 65536) (random 65536) (random 65536) (random 4096)
            (logior 8 (random 4)) (random 4096)
            (random 65536) (random 65536) (random 65536))))

(defun +snip/fk-suffix ()
  "22 alphanumerische Zeichen in Grossschreibung.
Entspricht RandomStringUtils.random(22, true, true).toUpperCase()."
  (let ((chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        (out ""))
    (dotimes (_ 22)
      (setq out (concat out (string (aref chars (random (length chars)))))))
    out))

(defun +snip/fk-name ()
  "Foreign-Key-Name wie IntelliJs \"FK_\" + RandomStringUtils..."
  (concat "FK_" (+snip/fk-suffix)))

(defun +snip/class-name ()
  "Name der umgebenden Klasse -- Ersatz fuer IntelliJs className().
Bevorzugt per tree-sitter die WIRKLICH umgebende Deklaration (also auch bei
inneren Klassen korrekt), sonst der Dateiname ohne Endung."
  (or (and (fboundp 'treesit-parser-list)
           (treesit-parser-list nil 'java)
           (ignore-errors
             ;; Wichtig: `treesit-node-at' liefert auf einer Leerzeile das erste
             ;; Blatt NACH dem Punkt. Im leeren Rumpf einer Klasse waere das die
             ;; naechste (innere) Klasse -- deshalb am letzten Zeichen VOR dem
             ;; Cursor ansetzen.
             (when-let* ((node (treesit-node-at
                                (save-excursion (skip-chars-backward " \t\n") (point))))
                         (decl (treesit-parent-until
                                node
                                (lambda (n)
                                  (member (treesit-node-type n)
                                          '("class_declaration" "interface_declaration"
                                            "enum_declaration" "record_declaration")))))
                         (name (treesit-node-child-by-field-name decl "name")))
               (treesit-node-text name t))))
      (and buffer-file-name (file-name-base buffer-file-name))
      "Class"))

(defun +snip/decap (text)
  "Ersten Buchstaben von TEXT klein schreiben -- wie IntelliJs decapitalize()."
  (if (or (null text) (string-empty-p text))
      (or text "")
    (concat (downcase (substring text 0 1)) (substring text 1))))

(defun +snip/capitalize-camel (text)
  "TEXT camelCase-isieren und ersten Buchstaben gross -- capitalize(camelCase(TEXT))."
  (if (or (null text) (string-empty-p text))
      (or text "")
    (let* ((parts (split-string text "[^A-Za-z0-9]+" t))
           (camel (if parts
                      (concat (car parts) (mapconcat #'capitalize (cdr parts) ""))
                    "")))
      (if (string-empty-p camel)
          camel
        (concat (upcase (substring camel 0 1)) (substring camel 1))))))

;; Fuer Templates, die denselben Zufallswert MEHRFACH einsetzen (z.B. Constraint-
;; Name und gleichnamiger Index). Ein zweiter Aufruf von `+snip/fk-name' wuerde
;; einen ANDEREN Namen liefern -- darum einmal pro Expansion via `yas-expand-env'
;; binden und im Template nur noch die Variable auslesen.
(defvar +snip--fk1 nil "Erster Foreign-Key-Name der laufenden Snippet-Expansion.")
(defvar +snip--fk2 nil "Zweiter Foreign-Key-Name der laufenden Snippet-Expansion.")

;; `className()' MUSS ueber `yas-expand-env' laufen: yasnippet wertet die
;; Backtick-Ausdruecke im Template erst aus, wenn der Template-Text schon im
;; Buffer steht. `+snip/class-name' wuerde dann die Template-Zeile
;; "public static class ...Configuration" selbst als Klasse erkennen (aus
;; `daoconf' wurde so "ConfigurationConfiguration"). Das EXPAND-ENV wird
;; dagegen VOR dem Einfuegen ausgewertet und sieht den unveraenderten Buffer.
(defvar +snip--class nil "Umgebende Klasse zum Zeitpunkt der Snippet-Expansion.")

;;; --------------------------------------------------------------------------
;;; IntelliJs `toReformat' nachbilden
;;; --------------------------------------------------------------------------
;; toReformat="true"  -> IntelliJ formatiert das Eingefuegte nach.
;;                       Gegenstueck: `yas-indent-line' = `auto' (yasnippet-Default).
;; toReformat="false" -> IntelliJ fuegt wortgetreu ein.
;;                       Gegenstueck: `yas-indent-line' = `fixed', sonst wuerde
;;                       der Major-Mode z.B. die handformatierten Liquibase-
;;                       Bloecke umbrechen.
;; Verteilung im Export: Java 8x true / 27x false, GC_Liquibase 12x true,
;; Liquibase 24x false, Kotlin 1x false, xsl 1x false.

(defconst +snip--reformat-keys
  '(;; Gruppe Java
    "elseif" "ifnull" "else" "if" "tun" "info" "ref" "now"
    ;; Gruppe GC_Liquibase (dort ist toReformat durchgehend "true")
    "sod_add_foreign_key" "sod_cs" "sod_cs_add_column" "sod_cs_drop_column"
    "sod_cs_drop_fk" "sod_cs_drop_index" "sod_cs_element_collection"
    "sod_cs_shadow" "sod_cs_solid" "sod_cs_table_zuo" "sod_fk_name" "sod_uuid")
  "Keys, die in IntelliJ toReformat=\"true\" haben.")

(defun +snip--apply-reformat (defs)
  "Bei allen DEFS mit toReformat=\"false\" das Nachformatieren abschalten.
Setzt dafuer `yas-indent-line' auf `fixed' im EXPAND-ENV der Definition."
  (mapcar
   (lambda (def)
     (if (member (car def) +snip--reformat-keys)
         def
       (let ((d (append def (make-list (max 0 (- 6 (length def))) nil))))
         (setf (nth 5 d) (append (nth 5 d) '((yas-indent-line 'fixed))))
         d)))
   defs))

;;; --------------------------------------------------------------------------
;;; Die Templates
;;; --------------------------------------------------------------------------

(defun +snippets/define-intellij-templates ()
  "Alle IntelliJ-Live-Templates in yasnippet registrieren."

  ;; ---------------------------- Gruppe Java -------------------------------
  (yas-define-snippets
   'java-mode
   (+snip--apply-reformat
    `(("logger"
      "private static final org.slf4j.Logger LOG = org.slf4j.LoggerFactory.getLogger(`+snip--class`.class);\n"
      "logger (Insert Log4j constant)" nil ("Java")
      ((+snip--class (+snip/class-name))))

     ("runmock" "@RunWith(MockitoJUnitRunner.class)" "runmock" nil ("Java"))

     ("momo"
      "private final $1 ${1:$(+snip/decap yas-text)} = Mockito.mock($1.class);$0"
      "momo (Mockito-Mock als Feld)" nil ("Java"))

     ("bean"
      "@Bean\npublic $1 ${1:$(+snip/decap yas-text)}() {\n  return new $1Impl();\n}$0"
      "bean" nil ("Java"))

     ("springbean"
      "@SpringBean\nprivate $1 ${1:$(+snip/decap yas-text)};$0"
      "springbean" nil ("Java"))

     ("autowired"
      "@Autowired\nprivate $1 ${1:$(+snip/decap yas-text)};$0"
      "autowired" nil ("Java"))

     ("mock"
      "@Mock\nprivate $1 ${1:$(+snip/decap yas-text)};$0"
      "mock" nil ("Java"))

     ("sut"
      "private $1 sut;\n\n@Before\npublic void setUp() {\n  sut = new $1Impl($0);\n}\n    \n    "
      "sut" nil ("Java"))

     ("sbh" "hql.append(\" $0 \");" "sbh" nil ("Java"))

     ("inj" "InjectorUtils.inject(this);" "inj (InjectThis)" nil ("Java"))

     ("daoconf"
      "@Import({EntDbConfig.class, DefaultSodalisBeanConfiguration.class})\npublic static class `+snip--class`Configuration {\n\n  @Bean\n  public $1 sut(final SessionFactory sessionFactory) {\n    final $1Impl dao = new $1Impl();\n    dao.setSessionFactory(sessionFactory);\n    return dao;\n  }\n  $0\n}"
      "daoconf (Spring Test Configuration)" nil ("Java")
      ((+snip--class (+snip/class-name))))

     ("concon"
      "@ContextConfiguration(classes = `+snip--class`Configuration.class)"
      "concon" nil ("Java")
      ((+snip--class (+snip/class-name))))

     ("serconf"
      "@Import(EntDbConfig.class)\npublic static class `+snip--class`Configuration {\n\n  @Bean\n  public $1 sut() {\n    return new $1Impl();\n  }\n  $0\n}"
      "serconf (Spring Test Configuration)" nil ("Java")
      ((+snip--class (+snip/class-name))))

     ("poserconf"
      "@Import({EntDbConfig.class, DefaultSodalisBeanConfiguration.class})\npublic static class $1ImplITConfiguration {\n\n  @Bean\n  public $1 sut() {\n    return new $1Impl();\n  }\n  $0\n}"
      "poserconf (Spring Test Configuration)" nil ("Java"))

     ("value" "final @Value(\"\\${$0}\") " "value" nil ("Java"))

     ("beandao"
      "@Bean\npublic $1 ${1:$(+snip/decap yas-text)}(final SessionFactory sessionFactory) {\n  final $1Impl dao = new $1Impl();\n  dao.setSessionFactory(sessionFactory);\n  return dao;\n}"
      "beandao" nil ("Java"))

     ("tssolid"
      "@Override\npublic String toString() {\n  return \"${1:`+snip--class`} [id=\" + getId() + \"]\";\n}"
      "tssolid (toString Solid)" nil ("Java")
      ((+snip--class (+snip/class-name))))

     ("tsshad"
      "@Override\npublic String toString() {\n  return \"${1:`+snip--class`} [id=\" + getId() + \", shadowId=\" + getShadowId() + \"]\";\n}"
      "tsshad (toString shadow)" nil ("Java")
      ((+snip--class (+snip/class-name))))

     ("rules"
      "@Rule\npublic $1 ${1:$(+snip/decap yas-text)} = new $1();"
      "rules (JUnit Rule)" nil ("Java"))

     ("std"
      "@Test\n@TestDefinition(module = ENT, key = CAT + \"$1\", name = \"$2\",\n      author = STH, datacontext = PVM) \n@TestDescription(\"$3\")\n@TestResultExpectation(\"$4\")\n@TestResultCriteria(\"\")\npublic void std$1() {\n  assureMitarbeiterIsSelected(Mitarbeiter.ZENTRAL);\n  \n  $0\n}"
      "std (Standardtest)" nil ("Java"))

     ("timeTravel"
      "@org.junit.Rule\npublic de.guidecom.sodalis.commons.infrastructure.TimeTravel timeTravel = new TimeTravel();"
      "timeTravel" nil ("Java"))

     ("funcpriv" "private $1 $2() {\n\n}" "funcpriv (private function)" nil ("Java"))
     ("funcpub"  "public $1 $2() {\n\n}"  "funcpub (public function)"  nil ("Java"))

     ("elseif" "else if($1){\n  $0\n} " "elseif (Add else-if branch)" nil ("Java"))
     ("ifnull" "if (${1:var} == null) {\n  $0\n}" "ifnull (Inserts 'if null' statement)" nil ("Java"))
     ("else"   "else {\n    $0\n} " "else" nil ("Java"))
     ("if"     "if ($1) {\n    $0\n}" "if" nil ("Java"))

     ("ngl"  "!="      "ngl"  nil ("Java"))
     ("gl"   "=="      "gl"   nil ("Java"))
     ("ngln" "!= null" "ngln" nil ("Java"))
     ("gln"  "== null" "gln"  nil ("Java"))

     ("tun"  "// tun: "      "tun"  nil ("Java"))
     ("info" "// info:"      "info" nil ("Java"))
     ("ref"  "// refactor: " "ref"  nil ("Java"))
     ("now"  "// now: "      "now"  nil ("Java")))))

  ;; --------------------------- Gruppe Kotlin ------------------------------
  (yas-define-snippets
   'kotlin-mode
   (+snip--apply-reformat
    `(("autowired"
       "@Autowired\nlateinit var $1 : ${1:$(+snip/capitalize-camel yas-text)}"
       "autowired" nil ("Kotlin")))))

  ;; ------------------ Gruppen Liquibase + GC_Liquibase --------------------
  ;; Hinweis: `\\${bigintType}' & Co. sind Liquibase-Properties und muessen fuer
  ;; yasnippet maskiert werden, sonst wuerde daraus ein Tab-Stop.
  (yas-define-snippets
   'nxml-mode
   (+snip--apply-reformat
    `(("precon"
      "<preConditions onFail=\"MARK_RAN\">\n  $0\n</preConditions>"
      "precon" nil ("Liquibase"))

     ("cs"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"tun\">\n  $0\n</changeSet>"
      "cs (leeres Changeset)" nil ("Liquibase"))

     ("createshadow"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"jkr\">\n    <createTable tableName=\"$1\">\n      <column autoIncrement=\"true\" name=\"shadowIdInternal\" type=\"\\${bigintType}\">\n        <constraints primaryKey=\"true\" primaryKeyName=\"PK__$1\"/>\n      </column>\n      <column name=\"deleteDateInternal\" type=\"\\${dateType}\"/>\n      <column name=\"importId\" type=\"varchar(255)\"/>\n      <column name=\"dirty\" type=\"\\${booleanType}\">\n        <constraints nullable=\"false\"/>\n      </column>\n      <column name=\"idInternal\" type=\"\\${bigintType}\"/>\n      <column name=\"shadowCreationDate\" type=\"\\${dateType}\">\n        <constraints nullable=\"false\"/>\n      </column>\n      <column name=\"shadowVersionInternal\" type=\"int\"/>\n      <column name=\"state\" type=\"varchar(255)\">\n        <constraints nullable=\"false\"/>\n      </column>\n      <column name=\"versionInternal\" type=\"int\"/>\n      <column name=\"shadowCreator_idInternal\" type=\"\\${bigintType}\">\n        <constraints nullable=\"false\"/>\n      </column>\n\n      $0\n    </createTable>\n  </changeSet>\n\n  <changeSet id=\"`(+snip/uuid)`\" author=\"jkr\">\n    <addForeignKeyConstraint baseColumnNames=\"shadowCreator_idInternal\"\n      baseTableName=\"$1\" constraintName=\"FK_$1_shadowCreator\"\n      deferrable=\"false\" initiallyDeferred=\"false\" onDelete=\"NO ACTION\" onUpdate=\"NO ACTION\"\n      referencedColumnNames=\"idInternal\" referencedTableName=\"SOD_SodalisBenutzer\" validate=\"true\"/>\n  </changeSet>"
      "createshadow" nil ("Liquibase"))

     ("createsolid"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"jkr\">\n    <createTable tableName=\"$1\">\n      <column autoIncrement=\"true\" name=\"idInternal\" type=\"\\${bigintType}\">\n        <constraints primaryKey=\"true\" primaryKeyName=\"PK__$1\"/>\n      </column>\n      <column name=\"deleteDateInternal\" type=\"\\${dateType}\"/>\n      <column name=\"importId\" type=\"varchar(255)\"/>\n      <column name=\"lastLockedDate\" type=\"\\${dateType}\"/>\n      <column name=\"lastMergedDate\" type=\"\\${dateType}\"/>\n      <column name=\"versionInternal\" type=\"int\"/>\n      \n      $0\n    </createTable>\n </changeSet>"
      "createsolid" nil ("Liquibase"))

     ("varchar"    "<column name=\"$0\" type=\"varchar(255)\"/>" "varchar" nil ("Liquibase"))
     ("bigint"     "<column name=\"$0\" type=\"\\${bigintType}\"/>" "bigint" nil ("Liquibase"))
     ("booleanLiqui"
      "<column name=\"$0\" type=\"\\${booleanType}\" defaultValue=\"0\">\n  <constraints nullable=\"false\"/>\n</column>"
      "booleanLiqui" nil ("Liquibase"))
     ("varcharMax" "<column name=\"$0\" type=\"clob\"/>" "varcharMax" nil ("Liquibase"))

     ("fk"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"jkr\">\n<addForeignKeyConstraint baseColumnNames=\"$1\"\n      baseTableName=\"$2\"\n      referencedColumnNames=\"idInternal\" referencedTableName=\"$3\"\n      constraintName=\"FK_$2_$3_$1\"\n      deferrable=\"false\" initiallyDeferred=\"false\" onDelete=\"NO ACTION\" onUpdate=\"NO ACTION\" validate=\"true\"/>\n</changeSet>\n\n <changeSet id=\"`(+snip/uuid)`\" author=\"jkr\">\n    <createIndex tableName=\"$2\"\n      indexName=\"FK_$2_$3_$1\">\n      <column name=\"$1\"/>\n    </createIndex>\n  </changeSet>"
      "fk" nil ("Liquibase"))

     ("datecolumn" "<column name=\"$0\" type=\"\\${dateType}\"/>" "datecolumn" nil ("Liquibase"))

     ("addcol_bool"
      "<addColumn tableName=\"$1\">\n    <column name=\"$2\" type=\"\\${booleanType}\" defaultValue=\"0\">\n        <constraints nullable=\"false\"/>\n    </column>\n</addColumn>"
      "addcol_bool" nil ("Liquibase"))

     ("addcol_string"
      "<addColumn tableName=\"$1\">\n    <column name=\"$2\" type=\"varchar(255)\" />\n</addColumn>"
      "addcol_string" nil ("Liquibase"))

     ("dropCol" "<dropColumn tableName=\"$1\" columnName=\"$2\"/>\n" "dropCol" nil ("Liquibase"))

     ("addnotnull"
      "<addNotNullConstraint tableName=\"$1\" columnName=\"$2\" columnDataType=\"$3\" defaultNullValue=\"$4\"/>\n"
      "addnotnull" nil ("Liquibase"))

     ("droptable" "<dropTable tableName=\"$1\"/>\n" "droptable" nil ("Liquibase"))

     ("addcol"
      "<addColumn tableName=\"$1\">\n    <column name=\"$2\" type=\"$3\" defaultValue=\"$4\">\n        <constraints nullable=\"$5\"/>\n    </column>\n</addColumn>"
      "addcol" nil ("Liquibase"))

     ("addcol_date"
      "<addColumn tableName=\"$1\">\n    <column name=\"$2\" type=\"\\${dateType}\" />\n</addColumn>"
      "addcol_date" nil ("Liquibase"))

     ("ctable"
      "<createTable tableName=\"$1\">\n    // addcol...\n</createTable>\n"
      "ctable" nil ("Liquibase"))

     ("addcol_int"
      "<addColumn tableName=\"$1\">\n    <column name=\"$2\" type=\"\\${bigintType}\">\n        <constraints nullable=\"false\"/>\n    </column>\n</addColumn>"
      "addcol_int" nil ("Liquibase"))

     ("dropNotNull"
      "<dropNotNullConstraint\n    tableName=\"$1\"\n    columnName=\"$2\"\n    columnDataType=\"$3\"/>"
      "dropNotNull" nil ("Liquibase"))

     ("nullable" "<constraints nullable=\"true\"/>"  "nullable" nil ("Liquibase"))
     ("notnull"  "<constraints nullable=\"false\"/>" "notnull"  nil ("Liquibase"))

     ("dropIndex" "<dropIndex tableName=\"$1\" indexName=\"$2\"/>" "dropIndex" nil ("Liquibase"))

     ("dropFkConstraint"
      "<dropForeignKeyConstraint baseTableName=\"$1\" constraintName=\"$2\"/>\n"
      "dropFkConstraint" nil ("Liquibase"))

     ;; --- Gruppe GC_Liquibase ---
     ;; `fkName' wird zweimal gebraucht (Constraint UND Index) -> einmal pro
     ;; Expansion via `yas-expand-env' binden, damit beide Stellen gleich sind.
     ("sod_add_foreign_key"
      "<addForeignKeyConstraint baseColumnNames=\"$2\" baseTableName=\"$1\"\n                             constraintName=\"`+snip--fk1`\" deferrable=\"false\"\n                             initiallyDeferred=\"false\"\n                             onDelete=\"NO ACTION\" onUpdate=\"NO ACTION\"\n                             referencedColumnNames=\"$4\"\n                             referencedTableName=\"$3\" validate=\"true\"/>\n                             \n<createIndex tableName=\"$1\" indexName=\"`+snip--fk1`\">\n      <column name=\"$2\"/>\n</createIndex>"
      "sod_add_foreign_key (Foreign-Key hinzufuegen)" nil ("GC_Liquibase")
      ((+snip--fk1 (+snip/fk-name))))

     ("sod_cs"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    \n</changeSet>"
      "sod_cs (leeres Changeset)" nil ("GC_Liquibase"))

     ("sod_cs_add_column"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n      <not>\n        <columnExists tableName=\"$1\" columnName=\"$2\"/>\n      </not>\n    </preConditions>\n    <addColumn tableName=\"$1\">\n      <column name=\"$2\" type=\"$3\"/>\n    </addColumn>\n</changeSet>"
      "sod_cs_add_column (Spalte hinzufuegen)" nil ("GC_Liquibase"))

     ("sod_cs_drop_column"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n        <columnExists tableName=\"$1\" columnName=\"$2\"/>\n    </preConditions>\n    <dropColumn tableName=\"$1\" columnName=\"$2\"/>\n</changeSet>"
      "sod_cs_drop_column (Spalte droppen)" nil ("GC_Liquibase"))

     ("sod_cs_drop_fk"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n      <foreignKeyConstraintExists foreignKeyName=\"$2\"\n                                  foreignKeyTableName=\"$1\"/>\n    </preConditions>\n    <dropForeignKeyConstraint baseTableName=\"$1\"\n                              constraintName=\"$2\"/>\n  </changeSet>"
      "sod_cs_drop_fk (Foreign-Key droppen)" nil ("GC_Liquibase"))

     ("sod_cs_drop_index"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n      <indexExists tableName=\"$1\" indexName=\"$2\"/>\n    </preConditions>\n    <dropIndex tableName=\"$1\" indexName=\"$2\"/>\n  </changeSet>"
      "sod_cs_drop_index (Index droppen)" nil ("GC_Liquibase"))

     ("sod_cs_element_collection"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n      <not>\n        <tableExists tableName=\"$1\"/>\n      </not>\n    </preConditions>\n\n    <createTable tableName=\"$1\">\n      <column name=\"$2\" type=\"\\${bigIntType}\">\n        <constraints nullable=\"false\"/>\n      </column>\n      <column name=\"$3\" type=\"$4\"/>\n    </createTable>\n\n    <addForeignKeyConstraint baseColumnNames=\"$2\" baseTableName=\"$1\"\n                             constraintName=\"`+snip--fk1`\" deferrable=\"false\"\n                             initiallyDeferred=\"false\"\n                             onDelete=\"NO ACTION\" onUpdate=\"NO ACTION\"\n                             referencedColumnNames=\"$6\"\n                             referencedTableName=\"$5\" validate=\"true\"/>\n                             \n    <createIndex tableName=\"$1\" indexName=\"`+snip--fk1`\">\n          <column name=\"$2\"/>\n    </createIndex>\n  </changeSet>"
      "sod_cs_element_collection (Tabelle fuer @ElementCollection)" nil ("GC_Liquibase")
      ((+snip--fk1 (+snip/fk-name))))

     ("sod_cs_shadow"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n      <not>\n        <tableExists tableName=\"$1\"/>\n      </not>\n    </preConditions>\n       \n    <createTable tableName=\"$1\">\n      <column autoIncrement=\"true\" name=\"shadowIdInternal\" type=\"\\${bigintType}\">\n        <constraints nullable=\"false\" primaryKey=\"true\"\n                     primaryKeyName=\"pk_$1\"/>\n      </column>\n      <column name=\"deleteDateInternal\" type=\"\\${dateType}\"/>\n      <column name=\"importId\" type=\"varchar(255)\"/>\n      <column name=\"dirty\" type=\"\\${booleanType}\">\n        <constraints nullable=\"false\"/>\n      </column>\n      <column name=\"idInternal\" type=\"\\${bigintType}\"/>\n      <column name=\"shadowCreationDate\" type=\"\\${dateType}\">\n        <constraints nullable=\"false\"/>\n      </column>\n      <column name=\"shadowVersionInternal\" type=\"int\"/>\n      <column name=\"state\" type=\"varchar(255)\">\n        <constraints nullable=\"false\"/>\n      </column>\n      <column name=\"versionInternal\" type=\"int\"/>\n      <column name=\"shadowCreator_idInternal\" type=\"\\${bigintType}\">\n        <constraints nullable=\"false\"/>\n      </column>\n    </createTable>\n\n    <addForeignKeyConstraint baseColumnNames=\"shadowCreator_idInternal\"\n                             baseTableName=\"$1\"\n                             constraintName=\"fk_$1_shCrId\"\n                             deferrable=\"false\"\n                             initiallyDeferred=\"false\" onDelete=\"NO ACTION\" onUpdate=\"NO ACTION\"\n                             referencedColumnNames=\"idInternal\"\n                             referencedTableName=\"SOD_SodalisBenutzer\" validate=\"true\"/>\n                             \n     <createIndex tableName=\"$1\" indexName=\"fk_$1_shCrId\">\n      <column name=\"shadowCreator_idInternal\"/>\n    </createIndex>\n</changeSet>"
      "sod_cs_shadow (Tabelle fuer Shadow anlegen)" nil ("GC_Liquibase"))

     ("sod_cs_solid"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n      <not>\n        <tableExists tableName=\"$1\"/>\n      </not>\n    </preConditions>\n\n    <createTable tableName=\"$1\">\n        <column autoIncrement=\"true\" name=\"idInternal\" type=\"\\${bigintType}\">\n            <constraints nullable=\"false\" primaryKey=\"true\" primaryKeyName=\"pk_$1\"/>\n        </column>\n        <column name=\"versionInternal\" type=\"INT\"/>\n        <column name=\"lastLockedDate\" type=\"\\${dateType}\"/>\n        <column name=\"lastMergedDate\" type=\"\\${dateType}\"/>\n        <column name=\"importId\" type=\"VARCHAR(255)\"/>\n        <column name=\"deleteDateInternal\" type=\"\\${dateType}\"/>\n    </createTable>\n</changeSet>"
      "sod_cs_solid (Tabelle fuer Solid anlegen)" nil ("GC_Liquibase"))

     ("sod_cs_table_zuo"
      "<changeSet id=\"`(+snip/uuid)`\" author=\"CHANGE_TO_YOUR_OWN_NAME\">\n    <preConditions onFail=\"MARK_RAN\">\n      <not>\n        <tableExists tableName=\"$1\"/>\n      </not>\n    </preConditions>\n    \n    <createTable tableName=\"$1\">\n        <column name=\"$2\" type=\"\\${bigintType}\">\n            <constraints nullable=\"false\" primaryKey=\"true\"/>\n        </column>\n        <column name=\"$3\" type=\"\\${bigintType}\">\n            <constraints nullable=\"false\" primaryKey=\"true\"/>\n        </column>\n    </createTable>\n    <addForeignKeyConstraint baseColumnNames=\"$2\" baseTableName=\"$1\" constraintName=\"`+snip--fk1`\" referencedColumnNames=\"$5\" referencedTableName=\"$4\"/>\n    <addForeignKeyConstraint baseColumnNames=\"$3\" baseTableName=\"$1\" constraintName=\"`+snip--fk2`\" referencedColumnNames=\"$7\" referencedTableName=\"$6\"/>\n    \n    <createIndex tableName=\"$1\" indexName=\"`+snip--fk1`\">\n      <column name=\"$2\"/>\n    </createIndex>\n    <createIndex tableName=\"$1\" indexName=\"`+snip--fk2`\">\n      <column name=\"$3\"/>\n    </createIndex>\n</changeSet>"
      "sod_cs_table_zuo (Zuordnungstabelle @ManyToMany)" nil ("GC_Liquibase")
      ((+snip--fk1 (+snip/fk-name)) (+snip--fk2 (+snip/fk-name))))

     ("sod_fk_name"
      "FK_`(+snip/fk-suffix)`"
      "sod_fk_name (Foreign Key Namen generieren)" nil ("GC_Liquibase")))))

  ;; ---- IntelliJ-Context "OTHER" (praktisch ueberall): genid + sod_uuid ----
  (dolist (mode '(text-mode prog-mode))
    (yas-define-snippets
     mode
     (+snip--apply-reformat
      `(("genid"    "`(+snip/uuid)`" "genid (UUID generieren)"    nil ("xsl"))
        ("sod_uuid" "`(+snip/uuid)`" "sod_uuid (UUID generieren)" nil ("GC_Liquibase")))))))

;; `yas-reload-all' baut die Tabellen aus den VERZEICHNISSEN neu auf und wuerde
;; programmatisch definierte Snippets dabei verwerfen -> nach jedem Reload erneut
;; registrieren (passiert u.a. bei `doom sync' / `SPC h r r').
(with-eval-after-load 'yasnippet
  (+snippets/define-intellij-templates)
  (add-hook 'yas-after-reload-hook #'+snippets/define-intellij-templates))

;; Zweiter Zeitpunkt, an dem Tabellen mutieren: yasnippet laedt die
;; Verzeichnisse verzoegert (JIT) -- erst beim ersten Buffer eines Modes, also
;; NACH `yas-after-reload-hook'. Dabei wuerden gleichnamige Keys wieder
;; umgebogen (Dooms `if' ueber unser IntelliJ-`if'). Deshalb nach einem echten
;; Nachladen erneut registrieren; die Pruefung auf offene JIT-Auftraege haelt
;; den ~5 ms teuren Durchlauf von jeder `yas-minor-mode'-Aktivierung fern.
(defun +snippets--reassert-after-jit-a (orig &rest args)
  "ORIG (`yas--load-pending-jits') ausfuehren und danach ggf. neu registrieren."
  (let ((pending (and (boundp 'yas--scheduled-jit-loads)
                      (cl-some (lambda (mode) (gethash mode yas--scheduled-jit-loads))
                               (yas--modes-to-activate)))))
    (apply orig args)
    (when pending
      (+snippets/define-intellij-templates)
      ;; JIT kann die CAPF-Liste eines bereits offenen XML-Buffers nach dem
      ;; nxml-Hook erneut umsortieren. Alle Liquibase-Buffer sofort korrigieren.
      (dolist (buffer (buffer-list))
        (with-current-buffer buffer
          (when (derived-mode-p 'nxml-mode)
            (+snippets/prioritize-yas-in-xml)))))))

(with-eval-after-load 'yasnippet
  (advice-add 'yas--load-pending-jits :around #'+snippets--reassert-after-jit-a))

;; In XML steht `rng-completion-at-point' normalerweise vor `yasnippet-capf'.
;; `completion-at-point' verwendet aber nur die ERSTE Quelle, die Treffer
;; liefert: bei `cs' gewann daher ein XML-Wort wie `csardas', obwohl das
;; Liquibase-Snippet korrekt vorhanden war. Snippets kommen deshalb in XML
;; zuerst. Fuer jedes Kuerzel ohne Snippet liefert yasnippet nil und die
;; Schema-Completion (Tags, Attribute usw.) greift unveraendert danach.
(defun +snippets/prioritize-yas-in-xml ()
  "Live-Template-Vorschlaege vor XML-Schema-Vorschlaegen anzeigen.
Stellt die programmatisch definierten Liquibase-Snippets bei Bedarf erneut her:
yasnippets JIT-Lader kann die nxml-Tabelle nach unserem initialen Hook ersetzen."
  (when (and (bound-and-true-p yas-minor-mode)
             (fboundp 'yasnippet-capf))
    ;; `yas-lookup-snippet' sucht den Anzeigenamen, nicht den Trigger-Key.
    ;; Der Key ist `cs', der Name lautet bewusst ausführlicher.
    (unless (yas-lookup-snippet "cs (leeres Changeset)" 'nxml-mode t)
      (+snippets/define-intellij-templates))
    (setq-local completion-at-point-functions
                (cons #'yasnippet-capf
                      (delq #'yasnippet-capf completion-at-point-functions)))))

;; Am Ende des Mode-Hooks laufen: nxml/rng und yasnippet können CAPFs erst
;; während ihrer eigenen Hooks ergänzen.
(add-hook 'nxml-mode-hook #'+snippets/prioritize-yas-in-xml t)

;; Doom aktiviert `yas-minor-mode' bei manchen XML-Buffern erst NACH dem
;; `nxml-mode-hook' und hängt yasnippet-capf dabei wieder ans Ende. Dieser Hook
;; läuft nach dieser Aktivierung und macht die Reihenfolge auch beim Wechsel in
;; eine später geöffnete Liquibase-Datei deterministisch.
(defun +snippets/prioritize-yas-after-enable-h ()
  "Yasnippet-CAPF nach dessen Aktivierung in Liquibase-XML priorisieren."
  (when (derived-mode-p 'nxml-mode)
    (+snippets/prioritize-yas-in-xml)))

(add-hook 'yas-minor-mode-hook #'+snippets/prioritize-yas-after-enable-h t)

;; Absolut robust gegen nachträgliche CAPF-Mutationen (z.B. Doom-JIT-Loading):
;; unmittelbar vor der echten Completion die Liquibase-Tabelle und Reihenfolge
;; sicherstellen. Das ist im Normalfall nur eine Liste umsortieren, keine Suche.
(defun +snippets--prepare-xml-capf-a (&rest _)
  "Liquibase-Yasnippets direkt vor `completion-at-point' priorisieren."
  (when (derived-mode-p 'nxml-mode)
    (+snippets/prioritize-yas-in-xml)))

(advice-remove 'completion-at-point #'+snippets--prepare-xml-capf-a)
(advice-add 'completion-at-point :before #'+snippets--prepare-xml-capf-a)

;; Bereits geoeffnete Liquibase-Dateien erhalten die Reihenfolge sofort,
;; ohne dass sie geschlossen oder Emacs neugestartet werden muessen.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'nxml-mode)
      (+snippets/prioritize-yas-in-xml))))
