# Eisdiele Kasse – TMS Web Core Touch-Kasse

Browser-basierte Eisdielen-Kasse, geschrieben in Delphi 12.1 mit TMS Web Core
(Trial v2.4.6.1, kompiliert mit pas2js 2.3.1). Läuft im Browser auf Windows
und auf Android-Tablets, ist touch-optimiert und für den späteren Ausbau zur
PWA vorbereitet.

## Funktionsumfang (aktueller Stand)

- **Tisch-Verwaltung** für Tisch 1–8, Theke und Mitnahme
- **Eigener Warenkorb pro Tisch**, der beim Tischwechsel automatisch
  gespeichert wird – Nachbestellungen addieren sich zur bestehenden Bestellung
- **Tisch-Leiste** oben zeigt jederzeit alle offenen Tische mit ihrer Summe
- **MwSt-Logik**: Tische 1–8 standardmäßig Vor Ort (19 %), Theke und Mitnahme
  standardmäßig zum Mitnehmen (7 %); pro Tisch umschaltbar; Getränke immer 19 %
- **Artikel-Kacheln** in vier Kategorien: Eis, Becher, Waffel, Getränk
- **Netto/MwSt/Brutto-Splittung** im Warenkorb für den späteren Bondruck
- **Bar/Karte/Storno-Buttons** als Platzhalter für TSE-Anbindung und
  Kartenterminal
- **Responsive Layout**: am Tablet hochkant rutscht der Warenkorb unter die
  Kacheln

## Projektstruktur

```
EisdieleKasse/
├── EisdieleKasse.dpr      Projektdatei
├── EisdieleKasse.html     Project-HTML mit CSS und Boot-Wrapper
├── UMain.pas              Main-Unit mit Datenmodell und Form-Aufbau
├── UMain.dfm              Form-Definition (epIgnore, efCSS)
├── UMain.html             Platzhalter für Form-HTML (leer, wird nicht genutzt)
└── README.md              Dieses Dokument
```

Im Output-Verzeichnis `TMSWeb\Debug\` landen nach dem Compile:

```
EisdieleKasse.html         gerenderte HTML (vom Build-Prozess)
EisdieleKasse.js           kompilierte JS, ca. 2,4 MB
```

## Datenmodell

```
TProduct
├── Id, Cat, Nm (Name), Pr (Preis brutto), Ico (Emoji)
└── Vat19: Boolean (true = immer 19 %, z. B. Getränke)

TOrderItem
├── Product: TProduct
└── Qty: Integer

TTable
├── Id, Name, Mode (cmTakeAway / cmEatHere)
└── Items: array of TOrderItem
```

`TForm1` hält dynamische Arrays `FProducts`, `FTables` und einen Zeiger
`FActiveTable` auf den gerade aktiven Tisch. Wechsel des aktiven Tisches
ist O(1), weil nichts kopiert wird.

## Bekannte Stolperfallen mit TMS Web Core Trial 2.4.6.1

Diese fünf Punkte waren in der Trial-Version zu beheben. Bei einer
Vollversion oder neueren TMS-Web-Core-Releases können die Workarounds
schrittweise zurückgebaut werden.

### 1. pas2js Trial vergisst den rtl.run-Boot-Aufruf

Der pas2js-Output endet mit `});` und ohne den eigentlich erwarteten
`rtl.run('program');`-Aufruf am Dateiende. Folge: JS lädt, wird aber
nicht gestartet, Browser bleibt leer.

**Workaround in `EisdieleKasse.html`:**

```html
<script src="$(ProjectName).js"></script>
<script>
  if (typeof rtl !== 'undefined' && typeof rtl.run === 'function') {
    rtl.run('program');
  } else {
    alert('FEHLER: rtl ist nicht definiert.');
  }
</script>
```

### 2. Generics überfordern den Trial-Compiler

`TObjectList<T>` mit drei verschiedenen Typparametern (TProduct, TTable,
TOrderItem) bricht den JS-Output mittendrin ab – die ganze Pascal-Logik
fehlt am Ende.

**Workaround:** Statt Generics-Container dynamische Arrays:

```pascal
FProducts: array of TProduct;
FTables  : array of TTable;
```

Plus eigene Helper-Methoden `AddProduct`, `AddTable`, `FreeProducts`,
`FreeTables` zum Verwalten.

### 3. ElementPosition und ElementFont müssen explizit gesetzt werden

Default in TMS Web Core: Komponenten bekommen Inline-Styles mit
`position: absolute; width: 100px; height: 25px` etc. mitgegeben. Das
überschreibt CSS-Klassen via inline-Style-Priorität, alle Elemente
landen bei (0,0) übereinandergestapelt.

**Workaround:** auf jedem programmatisch erzeugten Control:

```pascal
Btn := TWebButton.Create(Self);
Btn.ElementPosition := epIgnore;   // keine inline position
Btn.ElementFont := efCSS;          // keine inline font-styles
Btn.Parent := pnlTop;
Btn.ElementClassName := 'mode-btn';
```

In der `UMain.dfm` analog auf dem Form-Level:

```
ElementClassName = 'host'
ElementFont = efCSS
ElementPosition = epIgnore
```

### 4. TMS injiziert anonyme div-Wrapper

Zwischen einem `<span class="kasse-root">` und seinen Kindern liegt ein
unstyled `<div>`. Folge: `.kasse-root { display: flex }` wirkt nicht auf
die Kinder, weil die nicht direkte Kinder sind. Grid- und Flex-Layouts
brechen zusammen.

**Workaround in CSS:**

```css
.kasse-root > div, .main > div, .cart > div, .totals > div /* etc. */ {
  display: contents !important;
}
```

`display: contents` macht den Wrapper für das Layout unsichtbar – die
Kinder werden für Flex/Grid wie direkte Kinder behandelt.

### 5. Inline-Styles brauchen !important-Override

Selbst mit `epIgnore` bleibt eine inline `width: 100px; height: 25px`
auf den span-Elementen. Folge: alles 100 × 25 Pixel groß, Layout
verkrüppelt.

**Workaround in CSS:** sämtliche Container-Klassen mit `!important`
auf `width: auto`, `height: auto` und gewünschten `display`-Modus
zwingen:

```css
.kasse-root, .topbar, .tables, .main, .cart, .row /* ... */ {
  display: block !important; width: auto !important; height: auto !important;
}
.kasse-root { display: flex !important; flex-direction: column !important; }
.topbar { display: flex !important; align-items: center !important; }
/* ... usw. ... */
```

## Build und Start

1. Projekt in Delphi 12.1 öffnen
2. **Projekt → Neu erstellen** (Strg+F9 reicht nicht für saubere
   HTML-Übernahme, lieber kompletter Rebuild)
3. F9 zum Starten – TMS Web Core öffnet den Browser automatisch über
   den eingebauten Dev-Server auf `http://localhost:8000/`
4. Bei Änderungen: Strg+F5 im Browser für Hard-Reload (Cache umgehen)

## Geplante nächste Schritte

| Modul | Aufwand | Beschreibung |
|---|---|---|
| **localStorage-Persistenz** | klein | Tische und offene Bestellungen überleben Browser-Refresh und Tablet-Neustart |
| **PWA-Konfiguration** | klein | `manifest.json` + Service Worker → Home-Screen-Icon, Offline-Betrieb auf Android |
| **Artikelverwaltung** | mittel | UI zum Anlegen/Ändern von Artikeln statt Hardcoding in `SeedProducts` |
| **Tagesabschluss / Z-Bericht** | mittel | Verkaufsliste mit CSV-Export für den Steuerberater |
| **Bondruck** | mittel | ESC/POS via Netzwerkdrucker (z. B. Epson TM-T20), HTTP-Brücke als Helper |
| **TSE-Anbindung** | groß | **Pflicht im Echtbetrieb**: Kassensicherungsverordnung. Cloud-TSE (fiskaly, Deutsche Fiskal) per REST oder Hardware-TSE (Swissbit USB) |
| **Mehrere Kassen synchron** | groß | REST-Backend (Supabase, eigene API) oder MQTT (HiveMQ Cloud) |

## TSE-Hinweis für Echtbetrieb

Sobald die Software echte Verkäufe abwickelt, schreibt die deutsche
Kassensicherungsverordnung eine zertifizierte TSE vor. Ohne TSE darf die
Kasse nicht eingesetzt werden. Optionen:

- **Cloud-TSE** (fiskaly, Deutsche Fiskal): einfache HTTPS-Anbindung,
  ca. 10–15 € pro Monat
- **Hardware-TSE** (Swissbit USB, Epson TSE-Drucker): einmalig teurer,
  funktioniert offline

Der Bon muss zusätzlich QR-Code, Signatur, Transaktionszähler und
Seriennummer der TSE enthalten – das übernimmt die TSE-API.

## Versionsinfo

- Delphi 12.1 Athens
- TMS Web Core Trial v2.4.6.1
- pas2js 2.3.1 (Build 2023-11-19)
- Getestet in Chrome (Windows, regulär und Inkognito)
