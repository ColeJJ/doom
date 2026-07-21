# Formatierung nach IntelliJ-Schema

Ziel: dieselbe Formatierung wie in IntelliJ (Schema `gcIntellijCodeStyle`).

## Wie es funktioniert

JDT.LS unterstuetzt fuer Java **kein** `.editorconfig`, sondern ein
Eclipse-Formatter-XML. Daher wurde dein IntelliJ-Schema in das Profil
[`formatter/gc-eclipse-format.xml`](../formatter/gc-eclipse-format.xml)
uebersetzt und in [`+java.el`](../+java.el) verdrahtet. Das originale
IntelliJ-Schema liegt als Referenz unter
[`formatter/gcIntellijCodeStyle.xml`](../formatter/gcIntellijCodeStyle.xml):

```elisp
(setq lsp-java-format-settings-url   ".../formatter/gc-eclipse-format.xml"
      lsp-java-format-settings-profile "gcIntellijCodeStyle"
      lsp-java-import-order ["" "java" "javax" "org" "com"])
```

Uebernommene Kernregeln (aus `gcIntellijCodeStyle`):

- Einrueckung: 2 Leerzeichen, Continuation 4, Tab-Size 2 (keine Tabs)
- Zeilenbreite 100 (Code und Kommentare)
- Klammern K&R (am Zeilenende)
- bis zu 3 Leerzeilen behalten; 2 Leerzeilen um Typdeklarationen
- keine Star-Imports; Import-Reihenfolge java/javax/org/com

## Formatieren

- `SPC c f` -> **Format nach IntelliJ-Profil** (`+format/intellij`): Region
  falls aktiv, sonst der ganze Buffer. Fuer Java/Kotlin ueber den JDT-Formatter
  mit dem Profil oben; in Nicht-LSP-Buffern Fallback auf `+format/region-or-buffer`.
- `SPC c F` -> **Format buffer/region** (`+format/region-or-buffer`, Dooms
  apheleia-Default -- z.B. fuer JSON/YAML/Shell/... ohne LSP-Profil).
- `SPC m =` -> `lsp-format-buffer` (JDT-Formatter, wie `SPC c f` fuer den Buffer)
- Region direkt: `M-x lsp-format-region`

Java/Kotlin werden bewusst **nicht** ueber `apheleia` formatiert (sonst
Google-Style-Konflikt). `apheleia` bleibt fuer andere Sprachen aktiv.

## Editier-Zeit & Nicht-Java-Dateien (.editorconfig)

Das `editorconfig`-Modul ist aktiv. Da der direkte Schreibzugriff ins
`entscheidungen`-Repo uebersprungen wurde, hier der Inhalt zum manuellen Anlegen
unter `entscheidungen/.editorconfig`:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{java,kt,kts}]
indent_size = 2
max_line_length = 100

[*.{xml,html,css,scss,less,js,ts,json,yml,yaml}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false
max_line_length = 120
```

## Feinjustierung / hoechste Treue

- Einzelne Regeln: Settings in `formatter/gc-eclipse-format.xml` anpassen
  (IDs siehe `org.eclipse.jdt.core.formatter.*`).
- Alternativ exakt-IntelliJ: in IntelliJ mit Plugin "Eclipse Code Formatter"
  ein Eclipse-XML exportieren und dieses statt des abgeleiteten Profils eintragen.
