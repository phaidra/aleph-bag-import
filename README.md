## Mapping MAB > MODS > DC

* [Record identifier](#record-identifier)
* [Related item identifier](#related-item-identifier)
* [Language](#language)
* [Geographical coordinates](#geographical-coordinates)
* [Roles and contributors](#roles-and-contributors)
* [Titles](#titles)
* [Constituent title](#constituent-title)
* [Series title](#series-title)
* [Edition statement](#edition statement)
* [Place of publication](#place-of-publication)
* [Publisher](#publisher)
* [Date of publication](#date-of-publication)
* [Extent](#extent)
* [Production method](#production-method)
* [Format](#format)
* [Footnotes](#footnotes)
* [Classification](#classefication)
* [Keyword chains](#keyword-chains)
* [Generated (not mapped) fields](#generated-not-mapped-fields)


### Record identifier

#### 001

###### MAB (JSON)
```json
{
  "i1" : "-",
  "subfield" : [ 
    {
      "content" : "AC08790778",
      "label" : "a"
    }
  ],
  "id" : "001",
  "i2" : "1"
}
```

###### MODS
```xml
<mods:identifier type="ac-number">AC08790778</mods:identifier>
```

###### DC
```xml
<dc:identifier>AC08790778</dc:identifier>
```

### ~~Related item identifier~~

#### 003 (ignored)

### Language

#### 037ba

###### MAB (JSON)
```json
{
  "i1" : "b",
  "id" : "037",
  "subfield" : [ 
    {
      "label" : "a",
      "content" : "ger"
    }
   ],
  "i2" : "1"
}
```

###### MODS
```xml
<mods:language>
  <mods:languageTerm authority="iso639-2b" type="code">ger</mods:languageTerm>
</mods:language>
```

###### DC
```xml
<dc:language>ger</dc:language>
```

### Geographical coordinates

#### 034-

Is not mapped into MODS but into a separate datastream called GEO  
If there is nothing in 034- then check 078k

Subfields
* a - ignore
* b - scale
* d - W
* e - E
* f - N
* g - S

###### MAB (JSON)
```json
{
  "subfield" : [ 
    {
      "label" : "a",
      "content" : "a"
    }, 
    {
      "label" : "b",
      "content" : "220000"
    }, 
    {
      "label" : "d",
      "content" : "E0124300"
    }, 
    {
      "label" : "e",
      "content" : "E0151700"
    }, 
    {
      "content" : "N0471200",
      "label" : "f"
    }, 
    {
       "content" : "N0462000",
       "label" : "g"
    }
  ],
  "id" : "078",
  "i2" : "1",
  "i1" : "k"
}
```

###### GEO
```xml
<kml:kml xmlns:kml="http://www.opengis.net/kml/2.2">
  <kml:Document>
    <kml:Placemark>
      <kml:Polygon>
        <kml:outerBoundaryIs>
          <kml:LinearRing>
            <kml:coordinates>46.3333333333333,12.7166666666667,0 46.3333333333333,15.2833333333333,0 47.2,15.2833333333333,0 47.2,12.7166666666667,0</kml:coordinates>
          </kml:LinearRing>
        </kml:outerBoundaryIs>
      </kml:Polygon>
    </kml:Placemark>
  </kml:Document>
</kml:kml>
```

###### DC
```xml
TBD
```

### Roles and contributors

#### 100/200

Could be:  
100 _ a, 104 a a, 108 a a … 196 a a  
100 b a, 104 b a, 108 b a … 196 b a  
100 _ p, 104 a p, 108 a p … 196 a p  
100 b p, 104 b p, 108 b p … 196 b p  
200 _ a, 204 a a, 208 a a … 296 a a  
200 b a, 204 b a, 208 b a … 296 b a  
200 _ p, 204 a p, 208 a p, 296 a p  
200 b p, 204 b p, 208 b p, 296 b p  

100... persons  
200... corporate entities  

Subfields  
* a - not GND normalized name
* p - GND normalized name (in case of 200 fields /corporate entities/ it's not 'p' but 'k','g' or 'b')
* 9 - GND identifier
* b - role

Role mapping
  
| MAB        | MODS           | Note  |
| ------------- | ------------- | ----- |
| [Bearb.] | edt | # Fällt im Englischen mit editor zusammen |
| [Hrsg.] | edt | |
| [Drucker] | prt | |
| [Ill.] | ill | |
| [Widmungsempfänger] | dte | # drm steht eigentlich für Technischer Zeichner, es gibt aber ansonsten nur Künstler - in beiden Fällen ist etwas anderes gemeint, aber Technischer Zeichner trifft es m.E.n. noch eher |
| [Zeichner] | drm | |
| [Mitarb.] | ctb | |
| [Kartograph] | ctg | |
| [Lithograph] | ltg | |
| [Stecher] | egr | |
  

If the role wasn't found then 
*  If field is 100 and indicator is 'a' or '-' then the role is 'author'
*  If indicator is 'b', the role is 'contributor'

If the name is a GND normalized name, then the attribute `authority=gnd` will be added. If there is a '9' subfield, it's the GND identifier - in this case two attributes are added `authorityURI=http://d-nb.info/gnd/` and `valueURI=http://d-nb.info/gnd/<GND identifier here>`

The names are parsed in a following way: (firstname),trim(lastname)
Following special characters are removed from the names: '<<','>>'
Firstname is ignored if it equals to `...`

Eg: `Mechel, Christian <<von>>` would be firstname: `Christian von` lastname: `Mechel`

###### MAB (JSON)
```json
{
  "id" : "100",
  "i1" : "b",
  "i2" : "1",
  "subfield" : [ 
    {
      "label" : "p",
      "content" : "Mechel, Christian <<von>>"
    }, 
    {
      "content" : "1737-1817",
      "label" : "d"
    }, 
    {
      "label" : "9",
      "content" : "(DE-588)116976659"
    }, 
    {
      "content" : "[Hrsg.]",
      "label" : "b"
    }
  ]
}
```

###### MODS
```xml
<mods:name authority="gnd" authorityURI="http://d-nb.info/gnd/" type="personal" valueURI="http://d-nb.info/gnd/116976659">
  <mods:namePart type="given">Christian von</mods:namePart>
  <mods:namePart type="family">Mechel</mods:namePart>
  <mods:role>
    <mods:roleTerm authority="marcrelator" type="code">edt</mods:roleTerm>
  </mods:role>
</mods:name>
```

###### DC
```xml
<dc:creator>Mechel, Christian von</dc:creator>
```

### Titles

With any indcator (indicator is the value of 'i1').

| MAB Field        | Subtitle pair field |  MODS title type |
| ------------- | ------------- | ----- |
| 304 | *none* | uniform |
| 310 | *none* | alternative |
| 341 | 343 | translated |
| 345 | 347 | translated |
| 349 | 351 | translated |
| 331 | 335 | *none* |

Following special characters are removed: '<<','>>'

###### MAB (JSON)
```json
{
  "i2" : "1",
  "subfield" : [ 
    {
      "content" : "Karte des Herzogthums Kaernten",
      "label" : "a"
    }
   ],
  "id" : "331",
  "i1" : "-"
}
```

###### MODS
```xml
<mods:titleInfo>
  <mods:title>Karte des Herzogthums Kaernten</mods:title>
</mods:titleInfo>
```

###### DC
```xml
<dc:title>Karte des Herzogthums Kaernten</dc:title>
```

### Constituent title

#### 361

With any indcator (indicator is the value of 'i1').

###### MAB (JSON)
```json
{
  "i2" : "1",
  "subfield" : [ 
    {
      "content" : "Karte des Herzogthums Kaernten",
      "label" : "a"
    }
   ],
  "id" : "331",
  "i1" : "-"
}
```

###### MODS
```xml
<mods:relatedItem type="constituent">
  <mods:titleInfo>
    <mods:title>Geologische Karte des Burst</mods:title>
  </mods:titleInfo>
</mods:relatedItem>
```

###### DC
```xml
<dc:relation>Geologische Karte des Burst</dc:relation>
```

###### DC terms
```xml
<dcterms:isPartOf xsi:type="dcterms:URI">Geologische Karte des Burst</dcterms:isPartOf>
```

### Series title

#### 451

With any indcator (indicator is the value of 'i1').

###### MAB (JSON)
```json

```

###### MODS
```xml
<mods:relatedItem type="series">
  <mods:titleInfo>
    <mods:title>Artaria's General-Karten der österreichischen und ungarischen Länder; Nr. 5 Trunk's Schulhandkarte</mods:title>
  </mods:titleInfo>
</mods:relatedItem>
```

###### DC
```xml
<dc:relation>Artaria's General-Karten der österreichischen und ungarischen Länder; Nr. 5 Trunk's Schulhandkarte</dc:relation>
```

###### DC terms
```xml
<dcterms:isPartOf xsi:type="dcterms:URI">Artaria's General-Karten der österreichischen und ungarischen Länder; Nr. 5 Trunk's Schulhandkarte</dcterms:isPartOf>
```


### Edition statement

#### 403

###### MAB (JSON)
```json
{
    "id" : "403",
    "subfield" : [ 
        {
            "content" : "3., erg. Aufl.",
            "label" : "a"
        }
    ],
    "i2" : "1",
    "i1" : "-"
}
```

###### MODS
```xml
<mods:originInfo>
  <mods:edition>3., erg. Aufl.</mods:edition>
</mods:originInfo>
```

###### DC
```xml
<dc:relation>3., erg. Aufl.</dc:relation>
```

###### DC terms
```xml
<dcterms:isVersionOf xsi:type="dcterms:URI">3., erg. Aufl.</dcterms:isVersionOf>
```

### Place of publication

#### 410 - Place of publication
#### 410a - Place of printing

The difference between place of publication and place of printing will be ignored.

###### MAB (JSON)
```json
{
    "subfield" : [ 
        {
            "label" : "a",
            "content" : "Klagenfurt"
        }
    ],
    "id" : "410",
    "i2" : "1",
    "i1" : "-"
}
```

###### MODS
```xml
<mods:originInfo>
  <mods:place>
    <mods:placeTerm type="text">Klagenfurt</mods:placeTerm>
  </mods:place>
</mods:originInfo>
```

###### DC
```xml
<dc:publisher>Klagenfurt</dc:publisher>
```

### Publisher

#### 412 - Publisher
#### 412a - Printer

The difference between publisher and printer will be ignored.

###### MAB (JSON)
```json
{
    "i2" : "1",
    "id" : "412",
    "subfield" : [ 
        {
            "content" : "Kleinmayr",
            "label" : "a"
        }
    ],
    "i1" : "-"
}
```

###### MODS
```xml
<mods:originInfo>
  <mods:publisher>Kleinmayr</mods:publisher>
</mods:originInfo>
```

###### DC
```xml
<dc:publisher>Kleinmayr</dc:publisher>
```

### Date of publication

#### 425a (if not found, then 425- is used)

###### MAB (JSON)
```json
{
    "subfield" : [ 
        {
            "content" : "1880",
            "label" : "a"
        }
    ],
    "id" : "425",
    "i2" : "1",
    "i1" : "a"
}, 
{
    "id" : "425",
    "subfield" : [ 
        {
            "label" : "a",
            "content" : "s.a. [ca. 1880]"
        }
    ],
    "i2" : "1",
    "i1" : "-"
}
```

###### MODS
```xml
<mods:originInfo>
  <mods:dateIssued encoding="w3cdtf" keyDate="yes">1880</mods:dateIssued>
</mods:originInfo>
```

###### DC
```xml
<dc:date>1880</dc:date>
```

### Extent

#### 433

With any indcator (indicator is the value of 'i1').

###### MAB (JSON)
```json
{
    "i2" : "1",
    "subfield" : [ 
        {
            "label" : "a",
            "content" : "1 Kt."
        }
    ],
    "id" : "433",
    "i1" : "c"
}
```

###### MODS
```xml
<mods:physicalDescription>
  <mods:extent>1 Kt.</mods:extent>
</mods:physicalDescription>
```

###### DC
```xml
<dc:description>1 Kt.</dc:description>
```

### Production method

#### 434

Indicator always '-' and subfield 'a'.

###### MAB (JSON)
```json
{
    "i2" : "1",
    "id" : "434",
    "subfield" : [ 
        {
            "label" : "a",
            "content" : "mehrfarb."
        }
    ],
    "i1" : "-"
}
```

###### MODS
```xml
<mods:physicalDescription>
  <mods:form type="productionmethod">mehrfarb.</mods:form>
</mods:physicalDescription>
```

###### DC
```xml
<dc:description>mehrfarb.</dc:description>
```

### Format

#### 435

Indicator always '-' and subfield 'a'.

###### MAB (JSON)
```json
{
    "i1" : "-",
    "i2" : "1",
    "id" : "435",
    "subfield" : [ 
        {
            "content" : "86 x 64 cm",
            "label" : "a"
        }
    ]
}
```

###### MODS
```xml
<mods:physicalDescription>
  <mods:extent>86 x 64 cm</mods:extent>
</mods:physicalDescription>
```

###### DC
```xml
<dc:description>86 x 64 cm</dc:description>
```

### Footnotes

#### 501, 507, 511, 512, 517, 525

| Field        | Indicator | Subfield |  
| ------------- | ------------- | ------------- |  
| 501 | _ | a |  
| 507 | _ | a, p |  
| 511 | _ | a |  
| 512 | _, a | [none] |  
| 517 | _, a, b, c | p |  
| 525 | _ | p + a |  


###### MAB (JSON)
```json
{
    "i1" : "-",
    "subfield" : [ 
        {
            "content" : "Mit Schraffen. - Mit statist. Übersicht. - Maßstab in graph. Form (Wr. Klafter). - Nebenkt. Stadtplan Klagenfurt",
            "label" : "a"
        }
    ],
    "id" : "501",
    "i2" : "1"
}
```

###### MAB (JSON) Example for 525 p+a
```
{
  "id" : "525",
  "i1" : "-",
  "i2" : "1",
  "subfield" : [ 
    {
      "label" : "p",
      "content" : "Aus"
    }, 
    {
      "content" : "Stielers Hand-Atlas",
      "label" : "a"
    }
  ]
}
```

###### MODS
```xml
<mods:note>Mit Schraffen. - Mit statist. Übersicht. - Maßstab in graph. Form (Wr. Klafter). - Nebenkt. Stadtplan Klagenfurt</mods:note>
```

###### DC
```xml
<dc:description>Mit Schraffen. - Mit statist. Übersicht. - Maßstab in graph. Form (Wr. Klafter). - Nebenkt. Stadtplan Klagenfurt</dc:description>
```

### Classification

#### 700fa - id 
#### 700fb - label

We only map the identifier (the label for the identifier is already available in Phaidra/Vocabulary server).

###### MAB (JSON)
```json
{
    "i1" : "f",
    "i2" : "1",
    "subfield" : [ 
        {
            "content" : "74.20",
            "label" : "a"
        }, 
        {
            "label" : "b",
            "content" : "Deutschland, Österreich, Schweiz <Geographie>"
        }
    ],
    "id" : "700"
}
```

###### MODS
```xml
<mods:classification authority="bkl">74.20</mods:classification>
```

###### DC
```xml
<dc:subject>Deutschland</dc:subject>
```

### Keyword chains

#### 902...947

Entries with the same field number (eg 902) represent one keyword chain. Each instance of the same field is a separate category. Eg if the field 902 is present 4 times, then there are 4 different categories of this keyword chain. The subfields (eg 'g', 'f',...) define the various types of keywords in the category.
Eg there can be a keyword chain like this:
```JSON
{
  "id" : "907",
  "i1" : "-",
  "i2" : "1",
  "subfield" : [ 
      {
        "label" : "g",
        "content" : "Hüningen"
      }, 
      {
        "content" : "Region",
        "label" : "z"
      }, 
      {
        "content" : "(DE-588)4746833-6",
        "label" : "9"
      }
  ]
}, 
{
  "id" : "907",
  "i1" : "-",
  "i2" : "1",
  "subfield" : [ 
    {
      "label" : "s",
      "content" : "Belagerung"
    }, 
    {
      "content" : "(DE-588)4125327-9",
      "label" : "9"
    }
  ]
}, 
{
  "id" : "907",
  "i1" : "-",
  "i2" : "1",
  "subfield" : [ 
    {
      "label" : "z",
      "content" : "Geschichte"
    }
  ]
}, 
{
  "id" : "907",
  "i1" : "-",
  "i2" : "1",
  "subfield" : [ 
    {
      "content" : "Altkarte",
      "label" : "f"
    }
  ]
}
```
Then this means a keyword chain like:
`Hüningen, Region; Belagerung; Geschichte; Altkarte`

In MODS, each keyword chain will be represented as a separate <subject> node with a separate child node for each category. If there are multiple subfields for one category (eg as in the example above, under one '907-' there are 'g', 'z' and '9' ) then these are separated by colon. Eg if 'g' is Hüningen and 'z' Region then it's `Hüningen, Region`. '9' is always an GND identifier - in this case the appropriate attributes will be set ('authority','authorityURI','valueURI' - see [Roles and contributors](#roles-and-contributors))

In DC, each chain will be represented as one <subject> node, with categories separated by semicolon: `Hüningen, Region; Belagerung; Geschichte; Altkarte`

Sometimes a subfield (eg 'z') can mean different things depending on context (that's why it's twice in the guide). One important example:  
* z subfield
  * If the category contains a GND identifier (it's saved in '9' subfield) the the subfield 'z' particularizes the 'g' keyword. Eg. since Hüningen is both a city and a region, 'g' will contain 'Hüningen' and 'z' will contain 'Region' to differentiate it from the city.  
  * If the category DOES NOT contain GND identifier, then 'z' is a temporal keyword (eg 'History')

The MAB/Aleph guide to subfields:
```
902     KETTENGLIED DER 1. SCHLAGWORTKETTE

  Unterfelder:

    p     = Name (GND)
    k     = Körperschaftsname (GND)
    e     = Kongressname (GND)
    g     = Gebietskörperschaftsname (GND)
    s     = Sachbegriff (GND)
    b     = Untergeordnete Körperschaft, untergeordnete Einheit (GND)
    n     = Zählung (GND)
    c     = Personen: Beiname, Gattungsname, Titulatur, Territorium (GND)
    c     = Kongresse: Ort des Kongresses (GND)
    h     = Identifizierender Zusatz (GND)
    d     = Personen: Lebensjahre (GND)
    d     = Kongresse: Datum des Kongresses (GND)
    x     = Allgemeine Unterteilung (GND)
    z     = Geografika: Geografische Unterteilung (GND)
    z     = Zeitschlagwort (ohne GND-IDNR)
    9     = GND-Identnummer
    t     = Titel (GND)
    f     = Titel: Erscheinungsjahr eines Werkes (GND)
    f     = Formschlagwort (ohne GND-IDNR)
    m     = Besetzung im Musikbereich (GND)
    n     = Titel: Zählung (GND)
    o     = Angabe des Musikarrangements (GND)
    u     = Teil eines Werkes (GND)
    r     = Tonart (GND)
    s     = Version (GND)

Beispiel für z Geografische Unterteilung:

    g Minnesota z Nordwest
    g Gastein z Region (= Umgebung von Gastein)

Beispiele für h-Zusatz:

    g Lippe h Fluss
```

Here is the subfield <-> child node mapping:

| Subfield        | Child node |
| ------------- | ------------- |
| k | `<name type="corporate"><namePart>` |  
| p | `<name type="personal"><namePart>` |  
| g | `<geographic>` |  
| f | `<genre>` |  
| s | `<topic>` |  
| z | `<temporal>` if the category does NOT contain GND identifier |  


###### MAB (JSON)
```json
{
    "i2" : "1",
    "subfield" : [ 
        {
            "content" : "Kärnten",
            "label" : "g"
        }, 
        {
            "content" : "(DE-588)4029175-3",
            "label" : "9"
        }
    ],
    "id" : "902",
    "i1" : "-"
}, 
{
    "i1" : "-",
    "i2" : "1",
    "id" : "902",
    "subfield" : [ 
        {
            "content" : "Karte",
            "label" : "f"
        }
    ]
},
```

###### MODS
```xml
<mods:subject>
  <mods:geographic authority="gnd" authorityURI="http://d-nb.info/gnd/" valueURI="http://d-nb.info/gnd/4029175-3">Kärnten</mods:geographic>
  <mods:topic>Karte</mods:topic>
</mods:subject>
```

###### DC
```xml
<dc:subject>Kärnten, Karte</dc:subject>
```

## Generated (not mapped) fields

For every map, following parts are generated automatically:
```xml
<mods:recordInfo>
  <mods:recordContentSource>Universitätsbibliothek Wien</mods:recordContentSource>
  <mods:recordOrigin>Maschinell erzeugt</mods:recordOrigin>
  <mods:languageOfCataloging>
    <mods:languageTerm authority="iso639-2b" type="code">ger</mods:languageTerm>
  </mods:languageOfCataloging>
  <mods:descriptionStandard>rakwb</mods:descriptionStandard>
</mods:recordInfo>

<mods:note lang="ger" type="statement of responsibility">Bestand der Kartensammlung der Fachbereichsbibliothek Geographie und Regionalforschung, Universität Wien</mods:note>

<mods:accessCondition type="use and reproduction">http://creativecommons.org/publicdomain/mark/1.0/</mods:accessCondition>
```

