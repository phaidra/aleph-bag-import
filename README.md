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

###### MAB (JSON)
```json
{
  "id" : "100",
  "subfield" : [ 
    {
      "content" : "Bayer, Michael",
      "label" : "a"
    }, 
    {
      "content" : "[Bearb.]",
      "label" : "b"
    }
  ],
  "i2" : "1",
  "i1" : "b"
}
```

###### MODS
```xml
<mods:name type="personal">
  <mods:namePart type="given">Michael</mods:namePart>
  <mods:namePart type="family">Bayer</mods:namePart>
  <mods:role>
    <mods:roleTerm authority="marcrelator" type="code">edt</mods:roleTerm>
  </mods:role>
</mods:name>
```

###### DC
```xml
<dc:creator>Bayer, Michael</dc:creator>
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

Indicator '-' ???

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

###### DC ???
```xml
<dc:description>mehrfarb.</dc:description>
```

### Format

#### 435

Indicator '-' ???

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

###### DC ???
```xml
<dc:description>86 x 64 cm</dc:description>
```

### Footnotes

#### 501, 507, 511, 512, 517, 525

Indicator '-' ???

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

###### MODS
```xml
<mods:note>Mit Schraffen. - Mit statist. Übersicht. - Maßstab in graph. Form (Wr. Klafter). - Nebenkt. Stadtplan Klagenfurt</mods:note>
```

###### DC ???
```xml
<dc:description>Mit Schraffen. - Mit statist. Übersicht. - Maßstab in graph. Form (Wr. Klafter). - Nebenkt. Stadtplan Klagenfurt</dc:description>
```

## Open questions
* 359 - should it not be mapped ??? Example for AC08790778:
```json
{
    "i2" : "1",
    "id" : "359",
    "subfield" : [ 
        {
            "content" : "zsgest. und gezeichnet von Michael Bayer",
            "label" : "a"
        }
    ],
    "i1" : "-"
}
```
