# Datenbank-Viewer (pgmacs)

IntelliJ-Datenbank-Tool-Aequivalent fuer Postgres: `pgmacs` (auf Basis `pg.el`).
Tabellen auflisten, Zeilen ansehen/editieren (paginiert), Foreign-Keys folgen,
SQL ausfuehren -- komplett in Emacs.

## Oeffnen

- `SPC o d` -> `+pg/open`: Verbindungs-Profil auswaehlen (wie "find file"),
  pgmacs oeffnet die Tabellenliste.
- Direkt: `M-x pgmacs` (Widget-Dialog) oder `M-x pgmacs-open-string`.

## Profile pflegen

In [`+java.el`](../+java.el), Variable `+pg-profiles` (Ports gem. Run-Config-Envs:
ent.db=5432, bas.db=5433):

```elisp
(defvar +pg-profiles
  '(("ENT - Postgres (5432)" . "user=USER host=localhost port=5432 dbname=DBNAME")
    ("BAS - Postgres (5433)" . "user=USER host=localhost port=5433 dbname=DBNAME")
    ("Guide-Client - magellan (5432)" . "user=sa host=localhost port=5432 dbname=magellan")))
```

`USER`/`DBNAME` an deine lokalen DBs anpassen.

## Passwoerter (nicht im Klartext)

In `~/.authinfo(.gpg)`:

```
machine localhost port 5432 login USER password GEHEIM
machine localhost port 5433 login USER password GEHEIM
```

## Bedienung (in pgmacs)

- `RET` auf einer Tabelle: Inhalt browsen
- in der Zeilenansicht: editieren, loeschen, neue Zeile
- `h` ruft die Hilfe/Keymap auf

## Alternative

Wer Multi-DB/JDBC mit Autocompletion braucht: `ejc-sql` (nicht installiert,
optional nachruestbar).
