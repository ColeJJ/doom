# IntelliJ Live Templates in Doom Emacs

Alle Live Templates aus dem IntelliJ-Settings-Export sind 1:1 als yasnippet-
Snippets uebernommen: **73 Templates** aus 5 Gruppen.

| IntelliJ-Gruppe | Anzahl | aktiv in |
|---|---|---|
| Java | 35 | `java-mode`, `java-ts-mode` |
| Liquibase | 24 | `nxml-mode` (XML) |
| GC_Liquibase | 11 | `nxml-mode` (XML) |
| Kotlin | 1 | `kotlin-mode`, `kotlin-ts-mode` |
| xsl + GC_Liquibase (Context "OTHER") | 2 | ueberall (`text-mode`/`prog-mode`) |

Definiert in [`+snippets.el`](../+snippets.el).

## Benutzung

| Aktion | Taste |
|---|---|
| Template einfuegen | Kuerzel tippen, dann `TAB` (Insert-State) |
| Liste aller Snippets im Buffer | `SPC i s` (`yas-insert-snippet`) |
| Zum naechsten/vorherigen Feld | `TAB` / `S-TAB` |
| Expansion abbrechen | `C-g` |
| Alle aktiven Tabellen ansehen | `M-x yas-describe-tables` |

Das `TAB` im Insert-State entscheidet kontextabhaengig: steht ein bekanntes Kuerzel
vor dem Cursor, expandiert es (`yas-expand`); laeuft schon ein Template, springt es
ins naechste Feld.

`java-ts-mode` erbt von `java-mode` und `kotlin-ts-mode` von `kotlin-mode`,
darum gilt jede Definition automatisch fuer beide Varianten.

## Gruppe Java

| Kuerzel | fuegt ein |
|---|---|
| `logger` | `private static final Logger LOG = ...getLogger(<Klasse>.class);` |
| `runmock` | `@RunWith(MockitoJUnitRunner.class)` |
| `momo` | `private final X x = Mockito.mock(X.class);` |
| `mock` | `@Mock private X x;` |
| `bean` | `@Bean public X x() { return new XImpl(); }` |
| `beandao` | `@Bean` mit `SessionFactory`-Setter fuer DAOs |
| `springbean` | `@SpringBean private X x;` |
| `autowired` | `@Autowired private X x;` |
| `sut` | `sut`-Feld + `@Before setUp()` |
| `daoconf` | Spring-Test-Configuration fuer DAOs (`@Import` + `sut`-Bean) |
| `serconf` | Spring-Test-Configuration fuer Services |
| `poserconf` | Spring-Test-Configuration fuer `...ImplIT` |
| `concon` | `@ContextConfiguration(classes = <Klasse>Configuration.class)` |
| `rules` | `@Rule public X x = new X();` |
| `timeTravel` | `@Rule` mit `TimeTravel` |
| `std` | Standardtest mit `@TestDefinition`/`@TestDescription`/... |
| `tssolid` | `toString()` mit `id` |
| `tsshad` | `toString()` mit `id` + `shadowId` |
| `value` | `final @Value("${...}")` |
| `inj` | `InjectorUtils.inject(this);` |
| `sbh` | `hql.append(" ... ");` |
| `funcpriv` / `funcpub` | leere private/public Methode |
| `if` / `else` / `elseif` / `ifnull` | Kontrollfluss |
| `gl` / `ngl` / `gln` / `ngln` | `==` / `!=` / `== null` / `!= null` |
| `tun` / `info` / `ref` / `now` | Kommentar-Marker |

## Gruppe Kotlin

| Kuerzel | fuegt ein |
|---|---|
| `autowired` | `@Autowired lateinit var x : X` (Typ wird aus dem Feldnamen abgeleitet) |

## Gruppe Liquibase (XML)

| Kuerzel | fuegt ein |
|---|---|
| `cs` | Changeset mit generierter UUID, `author="tun"` |
| `precon` | `<preConditions onFail="MARK_RAN">` |
| `createsolid` / `createshadow` | Tabelle fuer Solid bzw. Shadow (inkl. FK-Changeset) |
| `ctable` | `<createTable>`-Huelle |
| `varchar` / `varcharMax` / `bigint` / `datecolumn` / `booleanLiqui` | einzelne `<column>` |
| `addcol` / `addcol_bool` / `addcol_string` / `addcol_int` / `addcol_date` | `<addColumn>` |
| `dropCol` / `droptable` / `dropIndex` / `dropFkConstraint` | Drop-Operationen |
| `addnotnull` / `dropNotNull` / `nullable` / `notnull` | Constraints |
| `fk` | FK-Changeset + passendes Index-Changeset |

## Gruppe GC_Liquibase (XML)

| Kuerzel | fuegt ein |
|---|---|
| `sod_cs` | Changeset mit UUID, `author="CHANGE_TO_YOUR_OWN_NAME"` |
| `sod_cs_solid` / `sod_cs_shadow` | Tabelle fuer Solid bzw. Shadow, mit `preConditions` |
| `sod_cs_table_zuo` | Zuordnungstabelle fuer `@ManyToMany` (2 FKs + 2 Indizes) |
| `sod_cs_element_collection` | Tabelle fuer `@ElementCollection` |
| `sod_cs_add_column` / `sod_cs_drop_column` | Spalte hinzufuegen/droppen, je mit `preConditions` |
| `sod_cs_drop_fk` / `sod_cs_drop_index` | FK/Index droppen, mit `preConditions` |
| `sod_add_foreign_key` | FK-Constraint + gleichnamiger Index |
| `sod_fk_name` | `FK_` + 22 Zufallszeichen |

## Ueberall verfuegbar (IntelliJ-Context "OTHER")

| Kuerzel | fuegt ein |
|---|---|
| `genid` | UUID |
| `sod_uuid` | UUID |

## Wie die IntelliJ-Mechanik abgebildet ist

| IntelliJ | Doom Emacs |
|---|---|
| `$VAR$` mit `alwaysStopAt="true"` | Tab-Stop `$1`, `$2`, ... |
| `$END$` | Endposition `$0` |
| Variable mehrfach im Template | erste Stelle = Feld, weitere = Mirror (laeuft beim Tippen mit) |
| `className()` | `+snip/class-name` -- per tree-sitter die tatsaechlich umgebende Klasse, also auch bei inneren Klassen korrekt |
| `decapitalize(X)` | `+snip/decap` |
| `capitalize(camelCase(X))` | `+snip/capitalize-camel` |
| `groovyScript("UUID.randomUUID().toString()")` | `+snip/uuid` (`uuidgen`, klein geschrieben wie in Java) |
| `RandomStringUtils.random(22, true, true).toUpperCase()` | `+snip/fk-suffix` |
| `toReformat="true"` | `yas-indent-line` = `auto` (Major-Mode formatiert nach) |
| `toReformat="false"` | `yas-indent-line` = `fixed` (wortgetreu, nur um die Cursor-Einrueckung verschoben) |
| Context (`JAVA_DECLARATION`, `XML_TEXT`, ...) | Major-Mode der Snippet-Tabelle |

Templates, die denselben Zufallswert an zwei Stellen brauchen (`sod_add_foreign_key`,
`sod_cs_element_collection`, `sod_cs_table_zuo`: Constraint-Name **und** Index-Name),
erzeugen ihn einmal pro Expansion ueber `yas-expand-env` -- sonst stuenden dort zwei
verschiedene Namen.

## Zwei bewusste Abweichungen

1. **Vorbelegte und gleichzeitig anspringbare Variablen** gibt es in yasnippet nicht.
   In IntelliJ ist z.B. bei `momo` der Feldname `decapitalize(CLASSNAME)` vorbelegt und
   trotzdem editierbar. Hier ist er ein Mirror: er fuellt sich beim Tippen des Typs
   automatisch korrekt, laesst sich aber nicht separat aendern. Betroffen sind die
   abgeleiteten Namen in `momo`, `bean`, `beandao`, `mock`, `springbean`, `autowired`
   (Java + Kotlin) und `rules`.
2. **`toShortenFQNames="true"`** (IntelliJ kuerzt vollqualifizierte Namen und ergaenzt
   den Import) hat kein Gegenstueck. `logger` und `timeTravel` fuegen deshalb den
   vollqualifizierten Namen ein -- das kompiliert ohne Import. Verkuerzen bei Bedarf
   danach mit `SPC m o` (Imports ordnen).

## Eigene Templates ergaenzen

Zwei Wege:

- **In `+snippets.el`**: neuen Eintrag in `+snippets/define-intellij-templates`
  aufnehmen (Format: `(KUERZEL TEMPLATE NAME nil (GRUPPE) EXPAND-ENV)`).
- **Als Datei**: `M-x yas-new-snippet` legt eine Datei unter
  `snippets/<major-mode>/` an. Bei gleichem Kuerzel gewinnt die Datei-Variante
  **nicht** -- `+snippets.el` registriert sich danach erneut (siehe unten).

## Warum die Registrierung zweimal haengt

yasnippet baut seine Tabellen aus Verzeichnissen und wirft programmatisch definierte
Snippets dabei weg. Deshalb registriert `+snippets.el` sich an zwei Stellen neu:

- `yas-after-reload-hook` -- nach `yas-reload-all` (u.a. bei `doom sync`, `SPC h r r`).
- als Advice auf `yas--load-pending-jits` -- yasnippet laedt die Verzeichnisse
  verzoegert beim ersten Buffer eines Modes, also **nach** dem Reload-Hook. Ohne diesen
  zweiten Schritt wuerde z.B. Dooms mitgeliefertes `if` das IntelliJ-`if` verdraengen.
