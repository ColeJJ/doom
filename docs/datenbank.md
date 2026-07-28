# Datenbank-Viewer (pgmacs)

IntelliJ-Datenbank-Tool-Aequivalent fuer Postgres: `pgmacs` (auf Basis `pg.el`).
Tabellen auflisten, Zeilen ansehen/editieren (paginiert), Foreign-Keys folgen,
SQL ausfuehren -- komplett in Emacs.

## Oeffnen

- `SPC o d` -> `+pg/open`: Verbindungs-Profil auswaehlen (wie "find file"),
  pgmacs oeffnet die Tabellenliste.
- **`C-u SPC o d`** -> Profil waehlen und **direkt in die Tabellensuche** springen
  (wie IntelliJ Cmd+O ueber die DB): nach dem Verbinden oeffnet sich sofort die
  Tabellenauswahl per Completion. Gleichbedeutend: `M-x +pg/open-table`.
- Direkt: `M-x pgmacs` (Widget-Dialog) oder `M-x pgmacs-open-string`.

## SQL aus einer .sql-Datei ausfuehren (IntelliJ "Execute")

In einer `.sql`-Datei (bzw. `sql-mode`):

1. Statement(s) **markieren** -- oder einfach den Cursor **ins Statement** setzen
   (dann wird das Statement bis zum naechsten `;` genommen; steht der Cursor am
   Zeilenende hinter dem `;`, wird das gerade beendete Statement genommen).
2. Shortcut: **`SPC m s`** oder **`C-c C-c`** (`+pg/run-sql`).
3. Es erscheint die Abfrage **"Auf welcher DB ausfuehren?"** -> Profil aus
   `+pg-profiles` waehlen (das zuletzt gewaehlte ist vorausgewaehlt).
4. Das Ergebnis wird als **pgmacs-Tabelle** angezeigt (hjkl-Navigation etc.),
   mit einer IntelliJ-artigen **Statuszeile** oben: `[Zeit] <Status>  |  N rows affected in X ms  |  DB: <Profil>`. Zusaetzlich erscheint die Kurzform in der
   Echo-Zeile (z.B. `1 row affected in 3 ms`). Bei INSERT/UPDATE/DELETE ohne
   Ergebnismenge zeigt der Buffer den Status + betroffene Zeilen (keine Tabelle).

Mehrere `;`-getrennte Statements: Region markieren; angezeigt wird das Ergebnis
des letzten Statements.

## Tabellen suchen (wie IntelliJ)

In der pgmacs-Tabellenliste:

- **`o`**, **`s`** oder **`/`** -> `pgmacs-open-table`: Tabellenname per Completion
  suchen (Fuzzy, mit Icons) und direkt oeffnen. Das ist die IntelliJ-artige
  "nach Tabelle suchen"-Funktion.
- `g` aktualisiert die Liste, `TAB` springt zum naechsten Eintrag.
- `e` -> `pgmacs-run-sql`: beliebiges SQL im Minibuffer ausfuehren,
  `E` -> `pgmacs-run-buffer-sql`: SQL aus einem Buffer ausfuehren.

Fuer den schnellsten Weg von "nichts offen" zu "Tabelle X ansehen":
`C-u SPC o d` -> Profil -> Tabellenname tippen -> `RET`.

## Profile pflegen

In [`+java.el`](../+java.el), Variable `+pg-profiles` (Ports gem. Run-Config-Envs:
ent.db=5432, bas.db=5433):

```elisp
(defvar +pg-profiles
  '(("ENT - Postgres (5432)" . "user=ent host=localhost port=5432 dbname=Entscheidungen")
    ("BAS - Postgres (5433)" . "user=USER host=localhost port=5433 dbname=DBNAME")
    ("Guide-Client - magellan (5432)" . "user=sa host=localhost port=5432 dbname=magellan")))
```

`USER`/`DBNAME` an deine lokalen DBs anpassen.

## Passwoerter (nicht im Klartext, nicht im Git)

Die Profile in `+pg-profiles` enthalten KEIN `password=` mehr. Das Passwort holt
sich Emacs zur Laufzeit aus `~/.authinfo` (auth-source, liegt ausserhalb dieses
Repos -- landet also nie im Git). Datei anlegen/ergaenzen:

```
machine localhost port 5432 login ent password DEIN_PW
machine localhost port 5433 login ent password DEIN_PW
```

Anschliessend Rechte einschraenken: `chmod 600 ~/.authinfo`.
(Noch sicherer: `~/.authinfo.gpg` -- dann GPG-verschluesselt.)

## Bedienung (in pgmacs)

- `RET` auf einer Tabelle: Inhalt browsen
- `o`/`s`/`/`: Tabelle per Namenssuche oeffnen (Completion)
- in der Zeilenansicht: editieren, loeschen, neue Zeile
- `h` ruft die Hilfe/Keymap auf (zeigt alle Tasten)

## Alternative

Wer Multi-DB/JDBC mit Autocompletion braucht: `ejc-sql` (nicht installiert,
optional nachruestbar).

## Kein Einfrieren mehr bei nicht erreichbarer DB

`pg.el` verbindet **synchron**. Ist der Port geschlossen (falscher Port, DB/Docker
nicht gestartet, SSH-Tunnel zu), fror Emacs frueher bis zum OS-TCP-Timeout (~60-75s)
ein. Jetzt prueft `+pg--connect` den Port vorab per **nicht-blockierender Probe**
(3s Timeout). Ist er nicht erreichbar, kommt sofort:

> DB nicht erreichbar: localhost:5434 (laeuft der Postgres? richtiger Port? ...)

-- Emacs bleibt bedienbar. Wichtig: der **Port im Profil-String** (`port=...`) muss
zur laufenden DB passen; der Text im Profil-Namen (z.B. "(5434)") ist nur ein Label.

## Langsames/haengendes Oeffnen grosser DBs (COUNT(*) pro Tabelle)

Symptom: nach "Verbinde mit ..." tut sich lange nichts, Emacs muss hart geschlossen
werden. Ursache: `pgmacs` schaetzt Zeilenzahlen nur dann schnell (ueber `reltuples`
aus dem Katalog), wenn die DB **groesser** als `pgmacs-large-database-threshold`
(Default 100 MB) ist. Kleinere DBs -> teures `COUNT(*)` auf JEDE Tabelle. Beispiel
Entscheidungen: ~41 MB, 334 Tabellen -> 334 Scans nacheinander = minutenlanger Hang.

Fix (in `+java.el`, `after! pgmacs`): `(setq pgmacs-large-database-threshold 0)` ->
immer der schnelle Schaetz-Pfad, Tabellenliste erscheint sofort.

Hinweis: Bei nie `ANALYZE`-ten Tabellen ist die Schaetzung ungenau (teils `-1`).
Fuer korrekte Zahlen einmalig in der DB `ANALYZE;` ausfuehren, z.B. im Docker:
`docker exec dev-entscheidungen_db-1 psql -U ent -d Entscheidungen -c "ANALYZE;"`

## Kompletter Freeze beim Oeffnen (Worker-Thread-Deadlock)

Symptom: `pgmacs-open` friert Emacs KOMPLETT ein (auch `C-g`/`with-timeout` helfen
nicht, nur Hard-Close). Ursache: `pgmacs-use-worker-thread` (Default `t`) laesst den
Worker- und den Main-Thread auf DERSELBEN pg.el-Verbindung arbeiten -- bei vielen
Tabellen (Entscheidungen: 334) verklemmen sie sich auf dem Socket (Deadlock).
Messung: Verbinden 0.26s, Tabellenliste 0.01s (beides top), aber das threaded
Metadaten-Laden haengt endlos.

Fix (in `+java.el`, `after! pgmacs`): `(setq pgmacs-use-worker-thread nil)`. Dann
laufen alle Abfragen sequentiell im Main-Thread -> `pgmacs-open` ist in ~3s fertig
(334 Tabellen, lokale DB), kein Freeze mehr.

## Navigation in pgmacs (vim hjkl)

Die pgmacs-Tabellen laufen im emacs-state; darum sind hjkl auf Bewegung gelegt
(die pgmacs-Standardbelegung h/j/k wurde verschoben):

| Taste | Aktion |
|-------|--------|
| `j` / `k` | Zeile runter / hoch |
| `h` / `l` | Spalte links / rechts |
| `e` / `b` | Wortende vor / Wortanfang zurueck (vim) |
| `J` | Zeile als JSON (war `j`) |
| `K` | Zeile kopieren (war `k`) |
| `Q` | SQL interaktiv ausfuehren (war `e`) |
| `?` | Hilfe (alle pgmacs-Tasten) |
| `RET` | Zelle/Detail oeffnen, `w` = Wert editieren, `o` = andere Tabelle |
| `q` | Buffer schliessen |

Die Warnung *"Expected function pgmacs--paginated-next/-prev to be bound"* ist
harmlos (die Tasten `n`/`p` gibt es nur bei paginierten Tabellen >200 Zeilen) und
wird nicht mehr als Popup angezeigt.

